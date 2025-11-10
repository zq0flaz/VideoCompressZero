import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress_zero/video_compress_zero.dart';

/// Example demonstrating video compression with cancel functionality
/// Shows:
/// - Progress tracking
/// - Cancel during compression
/// - Status messages
/// - Event-based state updates
class CompressWithCancelExample extends StatefulWidget {
  const CompressWithCancelExample({Key? key}) : super(key: key);

  @override
  State<CompressWithCancelExample> createState() =>
      _CompressWithCancelExampleState();
}

class _CompressWithCancelExampleState extends State<CompressWithCancelExample> {
  Subscription? _subscription;
  double _progress = 0;
  bool _isCompressing = false;
  String _statusMessage = 'Ready to compress';
  MediaInfo? _originalInfo;
  MediaInfo? _compressedInfo;
  String? _selectedFilePath;

  @override
  void initState() {
    super.initState();
    _setupProgressListener();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  /// Setup progress listener for compression events
  void _setupProgressListener() {
    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      setState(() {
        _progress = progress;
        if (progress > 0 && progress < 100) {
          _statusMessage = 'Compressing... ${progress.toStringAsFixed(1)}%';
        }
      });
    });
  }

  /// Pick a video file from gallery or file picker
  Future<void> _pickVideo() async {
    try {
      File? file;

      if (Platform.isMacOS) {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: "Select a video",
          allowedExtensions: ['mov', 'mp4', 'avi', 'mkv'],
          type: FileType.custom,
        );
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
        }
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          file = File(pickedFile.path);
        }
      }

      if (file == null) {
        return;
      }

      setState(() {
        _selectedFilePath = file!.path;
        _statusMessage = 'Video selected: ${file.path.split('/').last}';
        _compressedInfo = null;
      });

      // Get original video info
      final info = await VideoCompress.getMediaInfo(file.path);
      setState(() {
        _originalInfo = info;
        _statusMessage =
            'Original: ${(info.filesize! / (1024 * 1024)).toStringAsFixed(2)}MB, '
            '${info.width}x${info.height}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error picking video: $e';
      });
    }
  }

  /// Start video compression
  Future<void> _startCompression() async {
    if (_selectedFilePath == null) {
      setState(() {
        _statusMessage = 'Please select a video first';
      });
      return;
    }

    if (_isCompressing) {
      setState(() {
        _statusMessage = 'Already compressing, please wait or cancel';
      });
      return;
    }

    setState(() {
      _isCompressing = true;
      _progress = 0;
      _statusMessage = 'Starting compression...';
      _compressedInfo = null;
    });

    try {
      await VideoCompress.setLogLevel(0);

      final info = await VideoCompress.compressVideo(
        _selectedFilePath!,
        quality: VideoQuality.Res960x540Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );

      if (info != null) {
        setState(() {
          _compressedInfo = info;
          _isCompressing = false;

          if (info.isCancel == true) {
            _statusMessage = 'Compression cancelled by user';
            _progress = 0;
          } else {
            _progress = 100;
            final originalSize = _originalInfo?.filesize ?? 0;
            final compressedSize = info.filesize ?? 0;
            final reduction = originalSize > 0
                ? ((originalSize - compressedSize) / originalSize * 100)
                : 0;

            _statusMessage =
                'Completed! Compressed: ${(compressedSize / (1024 * 1024)).toStringAsFixed(2)}MB '
                '(${reduction.toStringAsFixed(1)}% reduction)';
          }
        });
      } else {
        setState(() {
          _isCompressing = false;
          _statusMessage = 'Compression returned null';
        });
      }
    } catch (e) {
      setState(() {
        _isCompressing = false;
        _progress = 0;
        _statusMessage = 'Error: $e';
      });
    }
  }

  /// Cancel ongoing compression
  Future<void> _cancelCompression() async {
    if (!_isCompressing) {
      setState(() {
        _statusMessage = 'No compression in progress';
      });
      return;
    }

    try {
      setState(() {
        _statusMessage = 'Cancelling compression...';
      });

      await VideoCompress.cancelCompression();

      setState(() {
        _statusMessage = 'Cancellation requested';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error cancelling: $e';
      });
    }
  }

  /// Clear all data and reset
  void _reset() {
    setState(() {
      _selectedFilePath = null;
      _originalInfo = null;
      _compressedInfo = null;
      _progress = 0;
      _isCompressing = false;
      _statusMessage = 'Ready to compress';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress with Cancel Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _isCompressing
                  ? Colors.blue.shade50
                  : (_compressedInfo?.isCancel == true
                      ? Colors.orange.shade50
                      : Colors.grey.shade50),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isCompressing
                              ? Icons.hourglass_empty
                              : (_compressedInfo?.isCancel == true
                                  ? Icons.cancel
                                  : Icons.info_outline),
                          color: _isCompressing
                              ? Colors.blue
                              : (_compressedInfo?.isCancel == true
                                  ? Colors.orange
                                  : Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress Indicator
            if (_isCompressing || _progress > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress: ${_progress.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progress / 100,
                        backgroundColor: Colors.grey.shade300,
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Original Video Info
            if (_originalInfo != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Video',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Size',
                          '${(_originalInfo!.filesize! / (1024 * 1024)).toStringAsFixed(2)} MB'),
                      _buildInfoRow('Resolution',
                          '${_originalInfo!.width} x ${_originalInfo!.height}'),
                      _buildInfoRow('Duration',
                          '${(_originalInfo!.duration! / 1000).toStringAsFixed(2)} s'),
                      if (_originalInfo!.orientation != null)
                        _buildInfoRow(
                            'Orientation', '${_originalInfo!.orientation}°'),
                    ],
                  ),
                ),
              ),

            // Compressed Video Info
            if (_compressedInfo != null && _compressedInfo!.isCancel != true)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compressed Video',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Size',
                          '${(_compressedInfo!.filesize! / (1024 * 1024)).toStringAsFixed(2)} MB'),
                      _buildInfoRow('Resolution',
                          '${_compressedInfo!.width} x ${_compressedInfo!.height}'),
                      _buildInfoRow('Duration',
                          '${(_compressedInfo!.duration! / 1000).toStringAsFixed(2)} s'),
                      if (_originalInfo != null)
                        _buildInfoRow(
                          'Reduction',
                          '${((_originalInfo!.filesize! - _compressedInfo!.filesize!) / _originalInfo!.filesize! * 100).toStringAsFixed(1)}%',
                          valueColor: Colors.green,
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('Select Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isCompressing ? null : _startCompression,
              icon: const Icon(Icons.compress),
              label: const Text('Start Compression'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isCompressing ? _cancelCompression : null,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Compression'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Tap "Select Video" to choose a video file'),
                    const Text(
                        '2. Tap "Start Compression" to begin compression'),
                    const Text('3. Watch the progress bar and status updates'),
                    const Text('4. Tap "Cancel Compression" anytime to stop'),
                    const Text('5. Compare original vs compressed file info'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight:
                  valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
