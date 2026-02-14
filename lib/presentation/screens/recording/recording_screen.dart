import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:healthdoc_mobile/core/theme/app_theme.dart' show AppTheme;
import 'package:healthdoc_mobile/services/audio/audio_recording_service.dart';
import 'package:healthdoc_mobile/services/storage/local_storage_service.dart';
import 'package:healthdoc_mobile/services/app_service_initializer.dart';
import 'package:healthdoc_mobile/domain/entities/recording_session.dart';
import 'package:healthdoc_mobile/domain/entities/session_start_config.dart';
import 'package:healthdoc_mobile/core/utils/logger.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';



class RecordingScreen extends ConsumerStatefulWidget {
  final SessionStartConfig? startConfig;

  const RecordingScreen({super.key, this.startConfig});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final AudioRecordingService _audioService = AudioRecordingService();
  final LocalStorageService _storageService = LocalStorageService();
  
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  bool _hasPermission = false;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _audioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
    // Initialize services
    _initializeServices();
    // Initialize audio service and request permission when screen loads
    _initializeAudio();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize storage service
      await _storageService.initialize();
      
      // Get upload queue manager from app service initializer
      final uploadQueueManager = AppServiceInitializer.uploadQueueManager;
      if (uploadQueueManager == null) {
        AppLogger.w('Upload queue manager not initialized');
        return;
      }
      
      // Listen to upload progress
      uploadQueueManager.uploadProgress.listen((session) {
        if (mounted && session.id == _currentSessionId) {
          // Could show upload progress here if needed
          if (session.status == RecordingStatus.completed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Recording uploaded successfully!'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          } else if (session.status == RecordingStatus.failed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${session.uploadError ?? "Unknown error"}'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      });
    } catch (e) {
      AppLogger.e('Failed to initialize services', e);
    }
  }

  Future<void> _initializeAudio() async {
    try {
      // Check current permission status first
      final status = await Permission.microphone.status;
      print('Initial microphone permission status: $status');
      
      if (mounted) {
        setState(() {
          _hasPermission = status.isGranted;
          if (!status.isGranted) {
            if (status.isPermanentlyDenied) {
              _errorMessage = 'Microphone permission is permanently denied. Please enable it in Settings.';
            } else if (status.isDenied) {
              _errorMessage = 'Microphone permission is required to record audio. Tap "Request Permission" to continue.';
            } else {
              // Status is notDetermined - permission hasn't been requested yet
              _errorMessage = 'Microphone permission is required to record audio. Tap "Request Permission" to continue.';
            }
          } else {
            _errorMessage = null;
          }
        });
        
        // Initialize the audio service if permission is already granted
        if (status.isGranted) {
          await _audioService.initialize();
        }
      }
    } catch (e, stackTrace) {
      print('Error initializing audio: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize audio: $e';
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      // Check current status first
      final currentStatus = await Permission.microphone.status;
      print('Current microphone permission status: $currentStatus');
      
      // Request permission
      final status = await Permission.microphone.request();
      print('Permission request result: $status');
      
      if (mounted) {
        setState(() {
          _hasPermission = status.isGranted;
          if (status.isGranted) {
            _errorMessage = null;
            // Initialize audio service after permission is granted
            _audioService.initialize().then((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Microphone permission granted!'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            });
          } else if (status.isPermanentlyDenied) {
            _errorMessage = 'Microphone permission is permanently denied. Please enable it in Settings.';
          } else if (status.isDenied) {
            _errorMessage = 'Microphone permission was denied. Please grant permission to record audio.';
          } else {
            _errorMessage = 'Microphone permission status: $status. Please try again.';
          }
        });
      }
    } catch (e, stackTrace) {
      print('Error requesting permission: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to request permission: $e';
        });
      }
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      // Check current permission status
      final status = await Permission.microphone.status;
      
      // If not granted, request permission
      if (!status.isGranted) {
        final requestResult = await Permission.microphone.request();
        if (!requestResult.isGranted) {
          setState(() {
            _hasPermission = false;
            if (requestResult.isPermanentlyDenied) {
              _errorMessage = 'Microphone permission is permanently denied. Please enable it in Settings.';
            } else {
              _errorMessage = 'Microphone permission is required to record audio.';
            }
          });
          return;
        }
        // Permission granted, update state and initialize
        setState(() {
          _hasPermission = true;
        });
        await _audioService.initialize();
      }

      // Generate session ID and file path
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final directory = await getApplicationDocumentsDirectory();
      final extension = Platform.isIOS ? 'm4a' : 'aac';
      final filePath = '${directory.path}/recording_$_currentSessionId.$extension';

      await _audioService.startRecording(filePath);
      
      // Verify recording actually started
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_audioService.isRecording) {
        throw Exception('Recording failed to start. Please check microphone access and try again.');
      }
      
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
      
      AppLogger.i('Recording started successfully, session ID: $_currentSessionId');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    // Prevent multiple simultaneous stop calls
    if (!_isRecording) {
      AppLogger.w('Stop recording called but not currently recording');
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
        _isRecording = false; // Set immediately to prevent multiple calls
      });

      // Stop recording and get unencrypted file path
      final unencryptedPath = await _audioService.stopRecording();
      if (unencryptedPath == null || unencryptedPath.isEmpty) {
        throw Exception('Recording path is null or empty');
      }

      if (_currentSessionId == null) {
        throw Exception('Session ID is null');
      }

      final unencryptedFile = File(unencryptedPath);
      if (!await unencryptedFile.exists()) {
        // Try to find the file with different extensions or in different locations
        AppLogger.w('Recording file not found at: $unencryptedPath');
        
        final possibleExtensions = ['m4a', 'aac'];
        for (final ext in possibleExtensions) {
          final altPath = unencryptedPath.replaceAll(RegExp(r'\.(aac|m4a)$'), '.$ext');
          final altFile = File(altPath);
          if (await altFile.exists()) {
            AppLogger.i('Found recording file with .$ext extension');
            await _processRecordingFile(altFile);
            return;
          }
        }
        
        throw Exception('Recording file not found at: $unencryptedPath');
      }

      // Wait a bit more and verify file has content (with retry)
      int retries = 3;
      int fileSize = 0;
      
      while (retries > 0) {
        fileSize = await unencryptedFile.length();
        if (fileSize > 0) {
          break;
        }
        retries--;
        if (retries > 0) {
          AppLogger.w('File still empty, waiting 200ms before retry...');
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      if (fileSize == 0) {
        // Provide helpful error message
        final durationSeconds = _duration.inSeconds;
        throw Exception(
          'Recording file is empty (0 bytes). '
          'Recording duration was ${durationSeconds}s. '
          'This usually means the microphone did not capture any audio. '
          'Please check:\n'
          '1. Microphone permissions are granted\n'
          '2. You are testing on a physical device (iOS Simulator may not have working microphone)\n'
          '3. The microphone is not being used by another app\n'
          '4. Try recording for at least 2-3 seconds'
        );
      }

      // Check minimum file size (at least 1KB to ensure it's not just metadata)
      if (fileSize < 1024) {
        AppLogger.w('Recording file is very small: $fileSize bytes. This might indicate a problem.');
      }

      AppLogger.i('Recording file verified: ${unencryptedFile.path}, size: $fileSize bytes');

      await _processRecordingFile(unencryptedFile);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop recording: $e';
        _isRecording = false; // Ensure state is reset on error
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      AppLogger.e('Failed to stop recording', e);
    }
  }

  Future<void> _processRecordingFile(File unencryptedFile) async {
    // Encrypt and save the recording
    final encryptedFilePath = await _storageService.saveEncryptedAudio(
      unencryptedFile,
      _currentSessionId!,
    );

    // Delete unencrypted file
    try {
      await unencryptedFile.delete();
    } catch (e) {
      // Log but don't fail if temp file deletion fails
      AppLogger.w('Warning: Failed to delete unencrypted file: $e');
    }

    // Get current user from auth
    final authState = ref.read(currentUserProvider);
    final userId = authState.user?.id ?? 'unknown_user';

    // Use session config from Start Session screen when available
    final cfg = widget.startConfig;
    final patientIdentifier = (cfg?.patientIdentifier.trim().isNotEmpty ?? false)
        ? cfg!.patientIdentifier.trim()
        : 'temp_patient';
    final formTypes = cfg?.formTypes ?? const <String>[];
    final notes = (cfg?.notes != null && cfg!.notes!.trim().isNotEmpty)
        ? cfg.notes!.trim()
        : null;

    // Create recording session
    final session = RecordingSession(
      id: _currentSessionId!,
      userId: userId,
      patientIdentifier: patientIdentifier,
      formTypes: formTypes,
      encryptedFilePath: encryptedFilePath,
      duration: _duration.inSeconds,
      status: RecordingStatus.processing, // treated as "queued for upload"
      createdAt: DateTime.now(),
      localRetentionUntil: DateTime.now().add(
        const Duration(days: 30),
      ),
      notes: notes,
    );

    // Add to upload queue
    final uploadQueueManager = AppServiceInitializer.uploadQueueManager;
    if (uploadQueueManager != null) {
      await uploadQueueManager.enqueue(session);
    } else {
      AppLogger.w(
        'Upload queue manager not available, recording saved but not queued for upload',
      );
    }

    setState(() {
      _isPaused = false;
      _duration = Duration.zero;
      _currentSessionId = null;
    });

    if (!mounted) return;

    // Optional user feedback before redirect
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording saved. Upload will continue in background.'),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 2),
      ),
    );

    // Navigate back to main home screen, replacing history so user
    // cannot navigate back to the recording screen.
    context.go('/home');
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioService.pauseRecording();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pause recording: $e';
      });
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioService.resumeRecording();
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resume recording: $e';
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Recording'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error, color: AppTheme.errorColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_errorMessage!.contains('permanently denied') ||
                          _errorMessage!.contains('Settings'))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: CustomButton(
                            text: 'Open Settings',
                            onPressed: _openSettings,
                            icon: Icons.settings,
                            backgroundColor: AppTheme.accentColor,
                          ),
                        )
                      else if (_errorMessage!.contains('Request Permission') ||
                          _errorMessage!.contains('permission was denied'))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: CustomButton(
                            text: 'Request Permission',
                            onPressed: _requestPermission,
                            icon: Icons.mic,
                            backgroundColor: AppTheme.accentColor,
                          ),
                        ),
                    ],
                  ),
                ),

              // Recording indicator
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? (_isPaused
                          ? AppTheme.accentColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1))
                      : AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    _isRecording
                        ? (_isPaused ? Icons.pause : Icons.fiber_manual_record)
                        : Icons.mic,
                    size: 80,
                    color: _isRecording
                        ? (_isPaused ? AppTheme.accentColor : AppTheme.errorColor)
                        : AppTheme.primaryColor,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Duration display
              Text(
                _formatDuration(_duration),
                style: AppTheme.headingLarge.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Status text
              Text(
                _isRecording
                    ? (_isPaused ? 'Recording Paused' : 'Recording...')
                    : 'Ready to Record',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 48),

              // Control buttons
              if (!_isRecording)
                CustomButton(
                  text: _hasPermission ? 'Start Recording' : 'Request Permission',
                  onPressed: _hasPermission ? _startRecording : _requestPermission,
                  icon: Icons.mic,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: _isPaused ? 'Resume' : 'Pause',
                        onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                        icon: _isPaused ? Icons.play_arrow : Icons.pause,
                        backgroundColor: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        text: 'Stop',
                        onPressed: _stopRecording,
                        icon: Icons.stop,
                        backgroundColor: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
