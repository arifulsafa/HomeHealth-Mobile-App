import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:healthdoc_mobile/core/theme/app_theme.dart' show AppTheme;
import '../../providers/auth_provider.dart';
import '../../providers/recordings_provider.dart';
import '../../../domain/entities/recording_session.dart';
import '../../../services/app_service_initializer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _patientFilterController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _dateRange;
  bool _showFilters = false;

  @override
  void dispose() {
    _patientFilterController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateForList(RecordingListItem item) {
    final dt = item.remote?.createdAt ?? item.local?.createdAt;
    if (dt == null) return '-';
    return DateFormat('M/d/yyyy').format(dt.toLocal());
  }

  String _displayFormType(String value) {
    switch (value) {
      case 'PT Oasis':
        return 'PT Oasis';
      case 'PT Evaluation':
        return 'PT Evaluation';
      case 'PT Discharge':
        return 'PT Discharge';
      case 'PT Oasis Discharge':
        return 'PT Oasis Discharge';
      default:
        return value;
    }
  }

  String _displayStatus(String value) {
    final lower = value.toLowerCase();
    switch (lower) {
      case 'uploaded':
        return 'Uploaded';
      case 'processing':
        return 'Processing';
      case 'transcribed':
        return 'Transcribed';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'upload failed':
        return 'Upload Failed';
      default:
        if (value.isEmpty) return '-';
        return value[0].toUpperCase() + value.substring(1);
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
    );

    if (picked != null && mounted) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  bool _passesFilters(RecordingListItem item) {
    // Date filter
    if (_dateRange != null) {
      final dt = item.remote?.createdAt ?? item.local?.createdAt;
      if (dt != null) {
        final d = DateTime(dt.year, dt.month, dt.day);
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
        );
        if (d.isBefore(start) || d.isAfter(end)) {
          return false;
        }
      }
    }

    // Patient ID filter
    final patientFilter = _patientFilterController.text.trim().toLowerCase();
    if (patientFilter.isNotEmpty &&
        !item.patientIdentifier.toLowerCase().contains(patientFilter)) {
      return false;
    }

    // Free-text search (patient, forms, status)
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final haystack = [
        item.patientIdentifier,
        item.statusLabel,
        ...item.formTypes,
      ].join(' ').toLowerCase();
      if (!haystack.contains(q)) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final recordingsAsync = ref.watch(recordingsListProvider);

    // Avoid full-screen loader when background updates happen.
    final existingData = recordingsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        // title: const Text('HealthDoc'),
        actions: [
          TextButton.icon(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.primaryColor),
            ),
            onPressed: () {
              context.push('/start-session');
            },
            icon: const Icon(Icons.mic, size: 18, color: Colors.white),
            label: const Text('Start Session', style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(currentUserProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: (recordingsAsync.isLoading && existingData != null)
            ? _buildContent(context, ref, existingData, isRefreshing: true)
            : recordingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load recordings',
                    style: AppTheme.headingSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.toString(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(remoteRecordingsProvider);
                      ref.invalidate(localRecordingSessionsProvider);
                      ref.invalidate(recordingsListProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
                ),
                data: (result) => _buildContent(context, ref, result),
              ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    CombinedRecordingsResult result, {
    bool isRefreshing = false,
  }) {
    final showRemoteWarning = result.remoteError != null;
    final filteredItems =
        result.items.where(_passesFilters).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(remoteRecordingsProvider);
        ref.invalidate(localRecordingSessionsProvider);
        ref.invalidate(recordingsListProvider);
        await ref.read(recordingsListProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dashboard header
          Text(
            'Clinician Dashboard',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your patient documentation requests',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Cupertino search
          CupertinoSearchTextField(
            controller: _searchController,
            placeholder: 'Search by patient, forms, or status',
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),

          // Filter toggle row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_list),
                label: Text(_showFilters ? 'Hide Filters' : 'Show Filters'),
              ),
            ],
          ),

          AnimatedCrossFade(
            crossFadeState: _showFilters
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            firstChild: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _patientFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Patient ID',
                      hintText: 'Filter by patient identifier',
                    ),
                    onChanged: (_) {
                      setState(() {});
                      final current = ref.read(recordingsFilterProvider);
                      ref.read(recordingsFilterProvider.notifier).state =
                          current.copyWith(
                        patientIdentifier: _patientFilterController.text.trim().isEmpty
                            ? null
                            : _patientFilterController.text.trim(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _pickDateRange(context);
                            final current = ref.read(recordingsFilterProvider);
                            ref.read(recordingsFilterProvider.notifier).state =
                                current.copyWith(
                              fromDate: _dateRange?.start,
                              toDate: _dateRange?.end,
                            );
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _dateRange == null
                                ? 'Any date'
                                : '${DateFormat('M/d/yyyy').format(_dateRange!.start)} - '
                                    '${DateFormat('M/d/yyyy').format(_dateRange!.end)}',
                          ),
                        ),
                      ),
                      if (_dateRange != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Clear date filter',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _dateRange = null;
                            });
                            final current = ref.read(recordingsFilterProvider);
                            ref.read(recordingsFilterProvider.notifier).state =
                                current.copyWith(
                              fromDate: null,
                              toDate: null,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),

          if (showRemoteWarning)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Showing local recordings only (offline or server unavailable).',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

          Text(
            'Recent Recordings',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 12),

          if (filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  isRefreshing
                      ? 'Updating recordings...'
                      : 'No recordings match your filters',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...filteredItems.map((item) {
              final local = item.local;
              final canRetry =
                  local != null && local.status == RecordingStatus.failed;

              // Status chip color
              Color statusColor;
              switch (item.statusLabel.toLowerCase()) {
                case 'completed':
                case 'transcribed':
                  statusColor = Colors.green.withOpacity(0.15);
                  break;
                case 'processing':
                case 'uploading':
                  statusColor = AppTheme.accentColor.withOpacity(0.15);
                  break;
                case 'upload failed':
                case 'failed':
                  statusColor = AppTheme.errorColor.withOpacity(0.15);
                  break;
                default:
                  statusColor = const Color(0xFFE0E0E0);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD0D5DD),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    context.push('/recordings/${item.sessionId}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.patientIdentifier,
                                    style: AppTheme.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date: ${_formatDateForList(item)}',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _displayStatus(item.statusLabel),
                                style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (item.formTypes.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: -4,
                            children: item.formTypes
                                .map(
                                  (f) => Chip(
                                    label: Text(
                                      _displayFormType(f),
                                      style: AppTheme.bodySmall,
                                      
                                    ),
                                    backgroundColor: const Color(0xFFF2F4F7),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                context.push(
                                  '/recordings/${item.sessionId}',
                                );
                              },
                              child: const Text('More Info'),
                            ),
                            if (canRetry)
                              TextButton(
                                onPressed: () async {
                                  try {
                                    final mgr = AppServiceInitializer
                                        .uploadQueueManager;
                                    if (mgr == null) {
                                      throw Exception(
                                        'Upload queue not initialized',
                                      );
                                    }
                                    await mgr.retry(item.sessionId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Retry started'),
                                          backgroundColor:
                                              AppTheme.successColor,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Retry failed: $e',
                                          ),
                                          backgroundColor:
                                              AppTheme.errorColor,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Retry'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
