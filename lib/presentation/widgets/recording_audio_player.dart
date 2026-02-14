import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/logger.dart';
import '../../services/storage/local_storage_service.dart';

class RecordingAudioPlayer extends StatefulWidget {
  final String? audioUrl;
  final String? encryptedFilePath;

  const RecordingAudioPlayer({
    super.key,
    this.audioUrl,
    this.encryptedFilePath,
  });

  @override
  State<RecordingAudioPlayer> createState() => _RecordingAudioPlayerState();
}

class _RecordingAudioPlayerState extends State<RecordingAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  final LocalStorageService _storageService = LocalStorageService();

  bool _isLoading = false;
  String? _error;
  File? _tempDecryptedFile;
  String? _loadedKey;

  @override
  void initState() {
    super.initState();
    _loadSourceIfNeeded();
  }

  @override
  void didUpdateWidget(covariant RecordingAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.encryptedFilePath != widget.encryptedFilePath) {
      _loadSourceIfNeeded();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _cleanupTempFile();
    super.dispose();
  }

  Future<void> _cleanupTempFile() async {
    try {
      final f = _tempDecryptedFile;
      _tempDecryptedFile = null;
      if (f != null && await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      AppLogger.w('Failed to cleanup temp decrypted audio file: $e');
    }
  }

  String? _buildKey() {
    if (widget.encryptedFilePath != null && widget.encryptedFilePath!.isNotEmpty) {
      return 'enc:${widget.encryptedFilePath}';
    }
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      return 'url:${widget.audioUrl}';
    }
    return null;
  }

  Future<void> _loadSourceIfNeeded() async {
    final key = _buildKey();
    if (key == null) {
      setState(() {
        _error = 'No audio available for this recording.';
      });
      return;
    }
    if (_loadedKey == key) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _player.stop();
      await _cleanupTempFile();

      if (widget.encryptedFilePath != null && widget.encryptedFilePath!.isNotEmpty) {
        final decrypted = await _storageService.decryptAndGetAudio(
          widget.encryptedFilePath!,
        );
        _tempDecryptedFile = decrypted;
        await _player.setFilePath(decrypted.path);
      } else {
        await _player.setUrl(widget.audioUrl!);
      }

      _loadedKey = key;
    } catch (e) {
      AppLogger.e('Failed to load audio source', e);
      _loadedKey = null;
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: AppTheme.errorColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorColor),
              ),
            ),
            TextButton(
              onPressed: _loadSourceIfNeeded,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snap) {
              final state = snap.data;
              final playing = state?.playing ?? false;
              final processing = state?.processingState;
              final isBuffering = processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering;

              return Row(
                children: [
                  IconButton(
                    iconSize: 42,
                    onPressed: isBuffering
                        ? null
                        : () async {
                            final current = _player.playerState.processingState;
                            if (current == ProcessingState.completed) {
                              await _player.seek(Duration.zero);
                            }
                            if (_player.playing) {
                              await _player.pause();
                            } else {
                              await _player.play();
                            }
                          },
                    icon: isBuffering
                        ? const SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(playing ? Icons.pause_circle : Icons.play_circle),
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      builder: (context, durSnap) {
                        final duration = durSnap.data ?? Duration.zero;
                        return StreamBuilder<Duration>(
                          stream: _player.positionStream,
                          builder: (context, posSnap) {
                            final position = posSnap.data ?? Duration.zero;
                            final maxMs = duration.inMilliseconds > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1.0;
                            final posMs = position.inMilliseconds
                                .clamp(0, duration.inMilliseconds)
                                .toDouble();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Slider(
                                  value: posMs,
                                  max: maxMs,
                                  onChanged: (v) async {
                                    await _player.seek(
                                      Duration(milliseconds: v.toInt()),
                                    );
                                  },
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _format(position),
                                      style: AppTheme.bodySmall,
                                    ),
                                    Text(
                                      _format(duration),
                                      style: AppTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            widget.encryptedFilePath != null ? 'Source: Local' : 'Source: Server',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

