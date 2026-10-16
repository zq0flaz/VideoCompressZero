import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress_zero/video_compress_zero.dart';
import 'package:video_player/video_player.dart';

import 'compression_controller.dart';
import 'video_thumbnail.dart';

class CompressWithCancelExample extends StatefulWidget {
  const CompressWithCancelExample({super.key});

  @override
  State<CompressWithCancelExample> createState() =>
      _CompressWithCancelExampleState();
}

class _CompressWithCancelExampleState extends State<CompressWithCancelExample> {
  late final CompressionController _controller;
  Subscription? _subscription;

  @override
  void initState() {
    super.initState();
    _controller = CompressionController(
      pickVideo: () async {
        if (Platform.isMacOS) {
          final files = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['mov', 'mp4'],
              dialogTitle: 'Select a video');
          return files?.files.single.path;
        }
        return (await ImagePicker().pickVideo(source: ImageSource.gallery))
            ?.path;
      },
      readInfo: VideoCompress.getMediaInfo,
      compress: (path, quality, frameRate, audio) =>
          VideoCompress.compressVideo(path,
              quality: quality,
              frameRate: frameRate,
              includeAudio: audio,
              deleteOrigin: false),
      cancel: VideoCompress.cancelCompression,
      save: Gal.putVideo,
    );
    _subscription =
        VideoCompress.compressProgress$.subscribe(_controller.updateProgress);
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          return PopScope(
            canPop: !c.busy,
            child: Scaffold(
              appBar:
                  AppBar(title: const Text('Video Compress Zero'), actions: [
                IconButton(
                    tooltip: 'Video thumbnail',
                    icon: const Icon(Icons.image_outlined),
                    onPressed: c.busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => const VideoThumbnail()))),
                IconButton(
                    tooltip: 'Reset',
                    icon: const Icon(Icons.refresh),
                    onPressed: c.busy ? null : c.reset),
              ]),
              body: SafeArea(
                  child: Center(
                      child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Semantics(
                      liveRegion: true,
                      child: Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(c.message)))),
                  if (c.busy || c.progress > 0) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                        value: c.phase == CompressionPhase.picking ||
                                c.phase == CompressionPhase.saving
                            ? null
                            : c.progress / 100),
                    if (c.phase == CompressionPhase.compressing ||
                        c.phase == CompressionPhase.cancelling)
                      Text('${c.progress.toStringAsFixed(1)}%'),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<VideoQuality>(
                    initialValue: c.quality,
                    decoration: const InputDecoration(labelText: 'Quality'),
                    items: const [
                      DropdownMenuItem(
                          value: VideoQuality.LowQuality, child: Text('Low')),
                      DropdownMenuItem(
                          value: VideoQuality.MediumQuality,
                          child: Text('Medium')),
                      DropdownMenuItem(
                          value: VideoQuality.Res960x540Quality,
                          child: Text('540p')),
                      DropdownMenuItem(
                          value: VideoQuality.Res1280x720Quality,
                          child: Text('720p')),
                      DropdownMenuItem(
                          value: VideoQuality.Res1920x1080Quality,
                          child: Text('1080p')),
                    ],
                    onChanged: c.busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => c.quality = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                      initialValue: c.frameRate,
                      decoration:
                          const InputDecoration(labelText: 'Frame rate'),
                      items: [24, 30, 60]
                          .map((fps) => DropdownMenuItem(
                              value: fps, child: Text('$fps fps')))
                          .toList(),
                      onChanged: c.busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => c.frameRate = value);
                              }
                            }),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include audio'),
                      value: c.includeAudio,
                      onChanged: c.busy
                          ? null
                          : (value) => setState(() => c.includeAudio = value)),
                  FilledButton.icon(
                      onPressed: c.busy ? null : c.pick,
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('Select Video')),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                      onPressed: c.busy || c.path == null ? null : c.start,
                      icon: const Icon(Icons.compress),
                      label: const Text('Start Compression')),
                  if (c.phase == CompressionPhase.compressing ||
                      c.phase == CompressionPhase.cancelling) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: c.phase == CompressionPhase.compressing
                            ? c.requestCancel
                            : null,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Compression')),
                  ],
                  if (c.original != null)
                    _infoCard('Original video', c.original!),
                  if (c.result != null) ...[
                    _infoCard('Compressed video', c.result!),
                    Text(
                        'Size change: ${sizeChange(c.original?.filesize, c.result?.filesize)}'),
                    if (c.elapsed != null)
                      Text(
                          'Processing time: ${(c.elapsed!.inMilliseconds / 1000).toStringAsFixed(1)} s'),
                    const SizedBox(height: 12),
                    VideoPreview(
                        key: ValueKey(c.result!.path), path: c.result!.path!),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: c.busy ? null : c.saveResult,
                        icon: const Icon(Icons.save_alt),
                        label: Text(c.phase == CompressionPhase.saving
                            ? 'Saving…'
                            : 'Save to Gallery')),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                      'Choose a video, adjust quality, then start compression. Your original video is preserved. Preview the result before saving it to your gallery.'),
                ]),
              ))),
            ),
          );
        },
      );

  Widget _infoCard(String title, MediaInfo info) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Size: ${formatSize(info.filesize)}'),
          Text('Resolution: ${info.width ?? '–'} × ${info.height ?? '–'}'),
          Text('Duration: ${formatDuration(info.duration)}'),
        ]),
      ));
}

class VideoPreview extends StatefulWidget {
  const VideoPreview({super.key, required this.path});
  final String path;
  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final VideoPlayerController _player;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.path));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Preview unavailable. You can still save the video.');
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Text(_error!);
    if (!_player.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(children: [
      AspectRatio(
          aspectRatio: _player.value.aspectRatio > 0
              ? _player.value.aspectRatio
              : 16 / 9,
          child: VideoPlayer(_player)),
      ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _player,
          builder: (context, value, _) => TextButton.icon(
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(value.isPlaying ? 'Pause preview' : 'Play preview'),
                onPressed: () async {
                  try {
                    if (value.isPlaying) {
                      await _player.pause();
                    } else {
                      if (value.position >= value.duration) {
                        await _player.seekTo(Duration.zero);
                      }
                      await _player.play();
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() => _error =
                          'Could not play preview. You can still save the video.');
                    }
                  }
                },
              )),
    ]);
  }
}
