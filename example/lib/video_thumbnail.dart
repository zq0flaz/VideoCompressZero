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
  File? _thumbnailFile;

  @override
  Widget build(BuildContext context) {
    Future<void> getVideoThumbnail() async {
      File? file;

      if (Platform.isMacOS) {
        // final typeGroup =
        //     XTypeGroup(label: 'videos', extensions: ['mov', 'mp4']);
        final picked = await FilePicker.platform.pickFiles(
            dialogTitle: "videos",
            type: FileType.custom,
            allowedExtensions: ['mov', 'mp4']);
        final path = picked?.files.single.path;
        if (path != null) file = File(path);
      } else {
        final picker = ImagePicker();
        var pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) file = File(pickedFile.path);
      }

      if (file != null) {
        _thumbnailFile = await VideoCompress.getFileThumbnail(file.path);
        setState(() {
          debugPrint(_thumbnailFile.toString());
        });
      } else {
        return;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('File Thumbnail')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: getVideoThumbnail,
                child: const Text('Get File Thumbnail')),
            _buildThumbnail(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (_thumbnailFile != null) {
      return Container(
        padding: EdgeInsets.all(20.0),
        child: Image(image: FileImage(_thumbnailFile!)),
      );
    }
    return Container();
  }
}
