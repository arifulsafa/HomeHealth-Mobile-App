import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:io';
import '../../core/utils/logger.dart';
import '../../core/errors/failures.dart';
import '../../config/app_config.dart';

class AudioRecordingService {
  FlutterSoundRecorder? _recorder;
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  String? _currentFilePath;
  bool _isRecording = false;

  Stream<Duration> get durationStream => _durationController.stream;
  Duration get currentDuration => _currentDuration;
  bool get isRecording => _isRecording;

  Future<bool> checkPermissions() async {
    final microphoneStatus = await Permission.microphone.status;
    if (microphoneStatus.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }
    return microphoneStatus.isGranted;
  }

  Future<void> initialize() async {
    try {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();

      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.allowBluetooth,
      ));

      AppLogger.i('Audio recorder initialized successfully');
    } catch (e) {
      AppLogger.e('Audio session initialization failed', e);
      // Do not rethrow; allow caller to attempt recording and surface a clearer error
    }
  }

  Future<String> startRecording(String filePath) async {
    try {
      if (!await checkPermissions()) {
        throw RecordingFailure('Microphone permission denied');
      }

      if (_recorder == null) {
        await initialize();
      }

      final codec = Platform.isIOS ? Codec.aacMP4 : Codec.aacADTS;
      final sampleRate = Platform.isIOS ? 44100 : AppConfig.audioSampleRate;

      // Verify recorder is ready for selected codec
      if (!await _recorder!.isEncoderSupported(codec)) {
        AppLogger.w('Selected codec not supported: $codec');
      }

      _currentFilePath = filePath;
      _currentDuration = Duration.zero;
      _isRecording = true;

      // Ensure we are not overwriting a stale file handle
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        try {
          await existingFile.delete();
        } catch (e) {
          AppLogger.w('Failed to delete existing recording file: $e');
        }
      }

      // Start recording
      await _recorder!.startRecorder(
        toFile: filePath,
        codec: codec,
        bitRate: 128000,
        sampleRate: sampleRate,
        numChannels: AppConfig.audioChannels,
        audioSource: AudioSource.microphone,
      );

      // Verify recording actually started
      await Future.delayed(const Duration(milliseconds: 500));
      final isRecording = await _recorder!.isRecording;
      if (!isRecording) {
        _isRecording = false;
        throw RecordingFailure('Recording failed to start. Please check microphone access.');
      }

      _startTimer();

      AppLogger.i('Recording started successfully: $filePath');
      return filePath;
    } catch (e) {
      _isRecording = false;
      AppLogger.e('Failed to start recording', e);
      throw RecordingFailure('Failed to start recording: ${e.toString()}');
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording || _recorder == null) {
        AppLogger.w('Stop recording called but not currently recording');
        return _currentFilePath; // Return stored path if available
      }

      // Check minimum recording duration (at least 1 second)
      if (_currentDuration.inSeconds < 1) {
        AppLogger.w('Recording duration too short: ${_currentDuration.inSeconds}s');
        // Still try to stop, but warn caller
      }

      _stopTimer();
      _isRecording = false;
      
      String? path;
      try {
        path = await _recorder?.stopRecorder();
        AppLogger.i('Recording stopped, path from stopRecorder: $path');
      } catch (e) {
        AppLogger.w('stopRecorder() threw error, using stored path: $e');
      }
      
      // Use stored path as fallback if stopRecorder returns null/empty
      if (path == null || path.isEmpty) {
        path = _currentFilePath;
        AppLogger.i('Using stored file path: $path');
      }
      
      // Wait for file to be written (flutter_sound may write asynchronously)
      if (path != null) {
        final file = File(path);
        
        // Retry checking file existence and size with exponential backoff
        int retries = 5;
        int delayMs = 100;
        bool fileReady = false;
        
        while (retries > 0 && !fileReady) {
          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 0) {
              AppLogger.i('Recording file verified: $path, size: $fileSize bytes');
              fileReady = true;
              break;
            } else {
              AppLogger.w('File exists but is empty (0 bytes), waiting... (${6 - retries}/5)');
            }
          } else {
            AppLogger.w('File not found yet, waiting... (${6 - retries}/5)');
          }
          
          retries--;
          if (retries > 0) {
            await Future.delayed(Duration(milliseconds: delayMs));
            delayMs *= 2; // Exponential backoff: 100ms, 200ms, 400ms, 800ms
          }
        }
        
        if (!fileReady) {
          AppLogger.e('File not ready after retries: $path', null);
          // Still return path - let caller decide how to handle
        }
      }
      
      // Clear stored path after successful stop
      final resultPath = path;
      _currentFilePath = null;
      return resultPath;
    } catch (e) {
      _isRecording = false;
      AppLogger.e('Failed to stop recording', e);
      // Return stored path as last resort
      final fallbackPath = _currentFilePath;
      _currentFilePath = null; // Clear even on error
      if (fallbackPath != null) {
        AppLogger.w('Returning stored path as fallback: $fallbackPath');
        return fallbackPath;
      }
      throw RecordingFailure('Failed to stop recording: ${e.toString()}');
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _recorder?.pauseRecorder();
      _stopTimer();
      AppLogger.i('Recording paused');
    } catch (e) {
      AppLogger.e('Failed to pause recording', e);
      throw RecordingFailure('Failed to pause recording: ${e.toString()}');
    }
  }

  Future<void> resumeRecording() async {
    try {
      await _recorder?.resumeRecorder();
      _startTimer();
      AppLogger.i('Recording resumed');
    } catch (e) {
      AppLogger.e('Failed to resume recording', e);
      throw RecordingFailure('Failed to resume recording: ${e.toString()}');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentDuration = Duration(seconds: _currentDuration.inSeconds + 1);
      _durationController.add(_currentDuration);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    _stopTimer();
    await _recorder?.closeRecorder();
    _recorder = null;
    await _durationController.close();
  }

  Future<File?> getRecordingFile() async {
    if (_currentFilePath == null) return null;
    final file = File(_currentFilePath!);
    if (await file.exists()) {
      return file;
    }
    return null;
  }
}
