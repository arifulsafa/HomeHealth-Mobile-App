import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/recordings_repository.dart';
import '../../domain/entities/recording_session.dart';
import '../../domain/entities/remote_recording.dart';
import '../../services/app_service_initializer.dart';
import '../../services/storage/recording_session_store.dart';
import 'auth_provider.dart';

class RecordingListItem {
  final String sessionId;
  final RecordingSession? local;
  final RemoteRecording? remote;

  const RecordingListItem({
    required this.sessionId,
    this.local,
    this.remote,
  });

  DateTime get sortDate => (local?.createdAt ?? remote?.createdAt) ?? DateTime(0);

  bool get isLocalOnly => local != null && remote == null;

  String get patientIdentifier =>
      (remote?.patientIdentifier.isNotEmpty == true)
          ? remote!.patientIdentifier
          : (local?.patientIdentifier.isNotEmpty == true)
              ? local!.patientIdentifier
              : 'Unknown';

  List<String> get formTypes =>
      (remote?.formTypes.isNotEmpty == true)
          ? remote!.formTypes
          : (local?.formTypes ?? const <String>[]);

  String get statusLabel {
    // 1) Prefer backend status when available (transcribed/completed/etc.).
    final rs = remote?.status ?? '';
    if (rs.trim().isNotEmpty) {
      return rs;
    }

    // 2) Fall back to explicit local upload states for in-flight/failed sessions.
    if (local != null) {
      switch (local!.status) {
        case RecordingStatus.failed:
          return 'Upload failed';
        case RecordingStatus.uploading:
          return 'Uploading';
        case RecordingStatus.processing:
          return 'Pending upload';
        case RecordingStatus.completed:
          return 'Completed';
        case RecordingStatus.recording:
        case RecordingStatus.paused:
          // These shouldn't normally appear in the list.
          break;
      }
    }

    return 'Unknown';
  }
}

class CombinedRecordingsResult {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final List<RecordingListItem> items;
  final String? remoteError;

  const CombinedRecordingsResult({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.items,
    this.remoteError,
  });
}

class RecordingsFilter {
  final String? patientIdentifier;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? status;
  final String? sessionId;

  const RecordingsFilter({
    this.patientIdentifier,
    this.fromDate,
    this.toDate,
    this.status,
    this.sessionId,
  });

  RecordingsFilter copyWith({
    String? patientIdentifier,
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
    String? sessionId,
  }) {
    return RecordingsFilter(
      patientIdentifier: patientIdentifier ?? this.patientIdentifier,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class RecordingDetailsResult {
  final String sessionId;
  final RecordingSession? local;
  final RemoteRecording? remote;
  final String? remoteError;

  const RecordingDetailsResult({
    required this.sessionId,
    this.local,
    this.remote,
    this.remoteError,
  });
}

final recordingsRepositoryProvider = Provider<RecordingsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RecordingsRepository(apiClient);
});

/// Global filter state used by the dashboard / recordings list screens.
final recordingsFilterProvider =
    StateProvider<RecordingsFilter>((ref) => const RecordingsFilter());

final recordingSessionStoreProvider = Provider<RecordingSessionStore>((ref) {
  return AppServiceInitializer.recordingSessionStore ?? RecordingSessionStore();
});

final recordingSessionStoreChangesProvider = StreamProvider<void>((ref) {
  final store = ref.watch(recordingSessionStoreProvider);
  return store.changes;
});

final remoteRecordingsProvider =
    FutureProvider.autoDispose<PaginatedRecordings>((ref) async {
  final repo = ref.watch(recordingsRepositoryProvider);
  final filter = ref.watch(recordingsFilterProvider);

  return repo.fetchRecordings(
    page: 1,
    limit: 100,
    status: filter.status,
    patientIdentifier: filter.patientIdentifier,
    sessionId: filter.sessionId,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

final localRecordingSessionsProvider =
    FutureProvider.autoDispose<List<RecordingSession>>((ref) async {
  // Re-run when local store changes (failed uploads, retries, etc.)
  ref.watch(recordingSessionStoreChangesProvider);
  final store = ref.watch(recordingSessionStoreProvider);
  return store.getAll();
});

final recordingsListProvider =
    FutureProvider.autoDispose<CombinedRecordingsResult>((ref) async {
  final locals = await ref.watch(localRecordingSessionsProvider.future);
  PaginatedRecordings remote;
  String? remoteError;

  try {
    remote = await ref.watch(remoteRecordingsProvider.future);
  } catch (e) {
    // Still show local sessions when offline / backend unavailable.
    remoteError = e.toString();
    remote = const PaginatedRecordings(
      page: 1,
      limit: 100,
      total: 0,
      totalPages: 1,
      recordings: <RemoteRecording>[],
    );
  }

  final remoteBySessionId = <String, RemoteRecording>{
    for (final r in remote.recordings) r.sessionId: r,
  };

  final localRelevant = locals.where((s) {
    final activeLocal = s.status == RecordingStatus.failed ||
        s.status == RecordingStatus.processing ||
        s.status == RecordingStatus.uploading;

    // Also show local "completed" if server doesn't have it yet.
    final completedButMissing =
        s.status == RecordingStatus.completed && !remoteBySessionId.containsKey(s.id);

    return activeLocal || completedButMissing;
  }).toList();

  final addedSessionIds = <String>{};
  final items = <RecordingListItem>[];

  for (final s in localRelevant) {
    items.add(
      RecordingListItem(
        sessionId: s.id,
        local: s,
        remote: remoteBySessionId[s.id],
      ),
    );
    addedSessionIds.add(s.id);
  }

  for (final r in remote.recordings) {
    if (addedSessionIds.contains(r.sessionId)) continue;
    items.add(RecordingListItem(sessionId: r.sessionId, remote: r));
  }

  items.sort((a, b) => b.sortDate.compareTo(a.sortDate));

  return CombinedRecordingsResult(
    page: remote.page,
    limit: remote.limit,
    total: remote.total,
    totalPages: remote.totalPages,
    items: items,
    remoteError: remoteError,
  );
});

final recordingDetailsProvider =
    FutureProvider.family.autoDispose<RecordingDetailsResult, String>(
        (ref, sessionId) async {
  // Re-run when local store changes (retry, upload progress, etc.)
  ref.watch(recordingSessionStoreChangesProvider);

  final store = ref.watch(recordingSessionStoreProvider);
  final local = await store.getById(sessionId);

  final repo = ref.watch(recordingsRepositoryProvider);
  RemoteRecording? remote;
  String? remoteError;

  try {
    remote = await repo.fetchRecordingBySessionId(sessionId);
  } catch (e) {
    remoteError = e.toString();
  }

  return RecordingDetailsResult(
    sessionId: sessionId,
    local: local,
    remote: remote,
    remoteError: remoteError,
  );
});

