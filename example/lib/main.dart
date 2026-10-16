import 'package:flutter/material.dart';
import 'compress_with_cancel_example.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Video Compress Zero Example',
        theme:
            ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        home: const CompressWithCancelExample(),
      );
}
