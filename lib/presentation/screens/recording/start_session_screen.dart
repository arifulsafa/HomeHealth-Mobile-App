import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/session_start_config.dart';
import '../../widgets/custom_button.dart';

class StartSessionScreen extends ConsumerStatefulWidget {
  const StartSessionScreen({super.key});

  @override
  ConsumerState<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends ConsumerState<StartSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _notesController = TextEditingController();

  bool _oasisSelected = false;
  bool _dailyNoteSelected = false;
  bool _dischargeNoteSelected = false;
  bool _otherSelected = false;
  bool _showFormTypeError = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _patientIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> _selectedFormTypes() {
    // Must match backend ALLOWED_FORM_TYPES exactly:
    // PT Oasis, PT Discharge, PT Evaluation, PT Oasis Discharge
    final types = <String>[];
    if (_oasisSelected) types.add('PT Oasis');
    if (_dailyNoteSelected) types.add('PT Evaluation');
    if (_dischargeNoteSelected) types.add('PT Discharge');
    if (_otherSelected) types.add('PT Oasis Discharge');
    return types;
  }

  Future<void> _handleStartSession() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedTypes = _selectedFormTypes();
    if (selectedTypes.isEmpty) {
      setState(() {
        _showFormTypeError = true;
      });
      return;
    }

    setState(() {
      _showFormTypeError = false;
      _isSubmitting = true;
    });

    try {
      final config = SessionStartConfig(
        patientIdentifier: _patientIdController.text.trim(),
        formTypes: selectedTypes,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;
      // Navigate to recording screen with session config
      context.go('/recording', extra: config);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Start a Session'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Patient Identifier *',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _patientIdController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., PT-001, John Doe',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a patient identifier';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Form Types
                    Text(
                      'Form Types *',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _FormTypeCheckbox(
                          label: 'PT Oasis',
                          value: _oasisSelected,
                          onChanged: (v) {
                            setState(() {
                              _oasisSelected = v ?? false;
                            });
                          },
                        ),
                        _FormTypeCheckbox(
                          label: 'PT Evaluation',
                          value: _dailyNoteSelected,
                          onChanged: (v) {
                            setState(() {
                              _dailyNoteSelected = v ?? false;
                            });
                          },
                        ),
                        _FormTypeCheckbox(
                          label: 'PT Discharge',
                          value: _dischargeNoteSelected,
                          onChanged: (v) {
                            setState(() {
                              _dischargeNoteSelected = v ?? false;
                            });
                          },
                        ),
                        _FormTypeCheckbox(
                          label: 'PT Oasis Discharge',
                          value: _otherSelected,
                          onChanged: (v) {
                            setState(() {
                              _otherSelected = v ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_showFormTypeError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Please select at least one form type',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'All information can be edited once you finish recording',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Notes
                    Text(
                      'Notes (optional)',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Enter any relevant notes or instructions...',
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: const BorderSide(
                                color: Color(0xFFE0E0E0),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CustomButton(
                          text: 'Start Session',
                          onPressed:
                              _isSubmitting ? null : _handleStartSession,
                          isLoading: _isSubmitting,
                          icon: Icons.mic,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormTypeCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const _FormTypeCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(
          label,
          style: AppTheme.bodyMedium,
        ),
      ],
    );
  }
}

