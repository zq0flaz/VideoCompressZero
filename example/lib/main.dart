import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress_zero/video_compress_zero.dart';
import 'package:video_compress_zero_example/video_thumbnail.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MediaInfo? _info;
  // ignore: unused_field
  late Subscription _subscription;
  double _progress = 0;
  @override
  void initState() {
    super.initState();
    setState(() {
      _subscription = VideoCompress.compressProgress$.subscribe((progress) {
        debugPrint('progress: $progress');
        setState(() {
          _progress = progress;
        });
      });
    });
  }

  Future<void> _compressVideo() async {
    var file;
    if (Platform.isMacOS) {
      // final typeGroup = XTypeGroup(label: 'videos', extensions: ['mov', 'mp4']);
      // file = await openFile(acceptedTypeGroups: [typeGroup]);
      file = await FilePicker.platform
          .pickFiles(dialogTitle: "videos", allowedExtensions: ['mov', 'mp4']);
    } else {
      final picker = ImagePicker();
      var pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      file = File(pickedFile!.path);
    }
    if (file == null) {
      return;
    }
    await VideoCompress.setLogLevel(0);
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {}

    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.Res960x540Quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    setState(() {
      _info = info;
    });
  }

  void _saveToLocal() async {
    if (_info?.file == null) return;
    final result = await ImageGallerySaverPlus.saveFile(_info!.file!.path,
        isReturnPathOfIOS: true);
    print(result);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Dialog Title'),
          content: const Text('Saved to your gallery'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Compresses video info:',
                ),
                if (_info != null)
                  Text(
                    'Path: ${_info?.path ?? ""}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                if (_info != null)
                  Text(
                    'FileSize: ${((_info?.filesize ?? 0) / (1024 * 1024)).toStringAsFixed(2)}MB',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                if (_info != null)
                  Text(
                    'Dimension: ${_info?.width ?? 0} x ${_info?.height ?? 0}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                if (_info != null)
                  Text(
                    'Duration: ${((_info?.duration ?? 0) / 1000).toStringAsFixed(2)} s',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                SizedBox(
                  height: 20,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.grey,
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: LinearProgressIndicator(
                        value: _progress / 100,
                        color: Colors.blue,
                        backgroundColor: Colors.transparent,
                        minHeight: 10,
                      ),
                    ),
                    Center(
                      child: Text(
                        "Progress ${_progress.toStringAsFixed(2)}%",
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    )
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: _saveToLocal,
                  child: Text('Save to gallery'),
                ),
                InkWell(
                    child: Icon(
                      Icons.cancel,
                      size: 55,
                    ),
                    onTap: () {
                      VideoCompress.cancelCompression();
                    }),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => VideoThumbnail()),
                    );
                  },
                  child: Text('Test thumbnail'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => _compressVideo(),
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
