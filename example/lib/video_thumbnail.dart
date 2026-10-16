import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress_zero/video_compress_zero.dart';

class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({super.key});
  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  File? _thumbnail;
  bool _busy = false;
  String? _error;

  Future<void> _pickThumbnail() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String? path;
      if (Platform.isMacOS) {
        final files = await FilePicker.platform.pickFiles(
            type: FileType.custom, allowedExtensions: ['mov', 'mp4']);
        path = files?.files.single.path;
      } else {
        path =
            (await ImagePicker().pickVideo(source: ImageSource.gallery))?.path;
      }
      if (!mounted || path == null) return;
      final thumbnail = await VideoCompress.getFileThumbnail(path);
      if (mounted) setState(() => _thumbnail = thumbnail);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not create thumbnail. Check access or choose another video.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Video Thumbnail')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          FilledButton(
              onPressed: _busy ? null : _pickThumbnail,
              child: Text(_busy ? 'Creating thumbnail…' : 'Select Video')),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          if (_thumbnail != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Image.file(_thumbnail!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) =>
                        const Text('Thumbnail unavailable'))),
        ])),
      );
}
