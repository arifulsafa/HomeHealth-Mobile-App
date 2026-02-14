import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/logger.dart';
import '../../domain/entities/recording_session.dart';
import 'local_storage_service.dart';

class RecordingSessionStore {
  RecordingSessionStore({LocalStorageService? storageService})
      : _storageService = storageService ?? LocalStorageService();

  final LocalStorageService _storageService;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  File? _indexFile;
  final Map<String, RecordingSession> _sessionsById = {};
  bool _initialized = false;

  Stream<void> get changes => _changes.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    final recordingsDir = await _storageService.initialize();
    _indexFile = File(p.join(recordingsDir.path, 'recording_sessions.json'));

    if (!await _indexFile!.exists()) {
      await _indexFile!.create(recursive: true);
      await _indexFile!.writeAsString(
        jsonEncode({'version': 1, 'sessions': []}),
      );
    }

    await _loadFromDisk();
    await reconcileWithEncryptedFiles();
    _initialized = true;
  }

  Future<List<RecordingSession>> getAll() async {
    if (!_initialized) {
      await initialize();
    }

    final items = _sessionsById.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<RecordingSession?> getById(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }
    return _sessionsById[sessionId];
  }

  Future<void> upsert(RecordingSession session) async {
    if (!_initialized) {
      await initialize();
    }
    _sessionsById[session.id] = session;
    await _persist();
    _changes.add(null);
  }

  Future<void> delete(String sessionId) async {
    if (!_initialized) {
      await initialize();
    }
    _sessionsById.remove(sessionId);
    await _persist();
    _changes.add(null);
  }

  /// Ensure we have a session entry for every encrypted file on disk.
  /// This supports showing "failed uploads from local storage" even if metadata
  /// was not stored previously.
  Future<void> reconcileWithEncryptedFiles() async {
    try {
      final stored = await _storageService.getStoredRecordings();
      if (stored.isEmpty) return;

      bool changed = false;
      for (final file in stored) {
        final sessionId = p.basenameWithoutExtension(file.path);
        if (_sessionsById.containsKey(sessionId)) continue;

        // Minimal placeholder metadata; upload service already uses safe defaults.
        final placeholder = RecordingSession(
          id: sessionId,
          userId: 'unknown_user',
          patientIdentifier: 'temp_patient',
          formTypes: const <String>[],
          encryptedFilePath: file.path,
          duration: 0,
          status: RecordingStatus.failed,
          uploadError: 'Found encrypted audio without metadata (older session).',
          uploadAttempts: 0,
          createdAt: (await file.stat()).modified,
          localRetentionUntil: null,
        );
        _sessionsById[sessionId] = placeholder;
        changed = true;
      }

      if (changed) {
        await _persist();
        _changes.add(null);
      }
    } catch (e) {
      AppLogger.e('Failed to reconcile encrypted files with session store', e);
    }
  }

  Future<void> dispose() async {
    await _changes.close();
  }

  Future<void> _loadFromDisk() async {
    try {
      if (_indexFile == null) return;
      final raw = await _indexFile!.readAsString();
      if (raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final sessions = decoded['sessions'];
      if (sessions is! List) return;

      _sessionsById.clear();
      for (final item in sessions) {
        if (item is Map<String, dynamic>) {
          final session = RecordingSession.fromJson(item);
          if (session.id.isNotEmpty) {
            _sessionsById[session.id] = session;
          }
        } else if (item is Map) {
          final session = RecordingSession.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (session.id.isNotEmpty) {
            _sessionsById[session.id] = session;
          }
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load recording session store', e);
    }
  }

  Future<void> _persist() async {
    try {
      if (_indexFile == null) return;

      final data = {
        'version': 1,
        'sessions': _sessionsById.values.map((s) => s.toJson()).toList(),
      };

      final tmp = File('${_indexFile!.path}.tmp');
      await tmp.writeAsString(jsonEncode(data));
      try {
        await tmp.rename(_indexFile!.path);
      } catch (_) {
        // Some platforms won't overwrite on rename.
        if (await _indexFile!.exists()) {
          await _indexFile!.delete();
        }
        await tmp.rename(_indexFile!.path);
      }
    } catch (e) {
      AppLogger.e('Failed to persist recording session store', e);
    }
  }
}

