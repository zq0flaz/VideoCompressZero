import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_compress_zero/video_compress_zero.dart';
import 'package:video_compress_zero_example/main.dart';

const _timeout = Duration(minutes: 2);
const _probe = MethodChannel('video_compress_zero_example/media_probe');

Future<Map<String, dynamic>> _inspect(String path) async => (await _probe
    .invokeMapMethod<String, dynamic>('inspect', {'path': path})
    .timeout(_timeout))!;

Future<MediaInfo> _compress(
  String path, {
  bool includeAudio = true,
  int? startTime,
  int? duration,
  int frameRate = 30,
  bool deleteOrigin = false,
  VideoQuality quality = VideoQuality.DefaultQuality,
}) async {
  final info = await VideoCompress.compressVideo(
    path,
    quality: quality,
    startTime: startTime,
    duration: duration,
    includeAudio: includeAudio,
    frameRate: frameRate,
    deleteOrigin: deleteOrigin,
  ).timeout(_timeout);
  expect(info, isNotNull, reason: 'Compression must produce an output');
  expect(info!.isCancel, isFalse);
  expect(info.file!.existsSync(), isTrue);
  expect(info.file!.lengthSync(), greaterThan(0));
  expect(info.filesize, info.file!.lengthSync());
  expect(VideoCompress.isCompressing, isFalse);
  return info;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File source;
  late File portrait;

  setUpAll(() async {
    expect(
      Platform.isAndroid || Platform.isIOS,
      isTrue,
      reason: 'Run on an Android emulator or iOS simulator',
    );
    directory = await Directory.systemTemp.createTemp('video_compress_native_');
    Future<File> copy(String asset, String name) async {
      final data = await rootBundle.load('assets/integration/$asset');
      return File('${directory.path}/$name').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    source = await copy('synthetic.mp4', 'source with %20.mp4');
    portrait = await copy('rotated.mp4', 'portrait.mp4');
    final media = await _inspect(source.path);
    expect(media['audioTracks'], 1, reason: 'Fixture must contain real audio');
    expect((media['frameRate'] as num).toDouble(), closeTo(30, 1));
  });

  setUp(() async {
    expect(await VideoCompress.deleteAllCache().timeout(_timeout), isTrue);
  });

  tearDown(() async {
    // Do not delete files while a timed-out native writer is still using them.
    if (VideoCompress.isCompressing) {
      await VideoCompress.cancelCompression().timeout(_timeout);
    }
    await VideoCompress.deleteAllCache().timeout(_timeout);
  });

  tearDownAll(() async {
    VideoCompress.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets('example opens with compression disabled until selection', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Select a video to begin'), findsOneWidget);
    expect(find.text('Start Compression'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('metadata supports plain paths and file URIs', (tester) async {
    for (final path in [source.path, source.uri.toString()]) {
      final info = await VideoCompress.getMediaInfo(path).timeout(_timeout);
      expect(info.duration, closeTo(6000, 150));
      expect(info.width, 320);
      expect(info.height, 180);
      expect(info.filesize, source.lengthSync());
    }
  });

  testWidgets('thumbnails use milliseconds and preserve portrait orientation', (
    tester,
  ) async {
    final first = await VideoCompress.getByteThumbnail(
      source.path,
      position: 0,
    ).timeout(_timeout);
    final last = await VideoCompress.getByteThumbnail(
      source.path,
      position: 5000,
    ).timeout(_timeout);
    expect(first, isNotEmpty);
    expect(last, isNotEmpty);
    expect(first, isNot(orderedEquals(last!)));
    final file = await VideoCompress.getFileThumbnail(source.path)
        .timeout(_timeout);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));

    final info = await VideoCompress.getMediaInfo(portrait.path)
        .timeout(_timeout);
    expect(info.width, 180);
    expect(info.height, 320);
    final bytes = await VideoCompress.getByteThumbnail(
      portrait.path,
      position: 0,
    ).timeout(_timeout);
    final codec = await ui.instantiateImageCodec(bytes!);
    try {
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 180);
      expect(frame.image.height, 320);
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  });

  for (final audio in [true, false]) {
    testWidgets('trim selects 3 seconds at 15 fps; includeAudio=$audio', (
      tester,
    ) async {
      final info = await _compress(
        source.path,
        startTime: 2,
        duration: 3,
        frameRate: 15,
        includeAudio: audio,
      );
      expect(info.duration, closeTo(3000, 200));
      final media = await _inspect(info.path!);
      expect(media['audioTracks'], audio ? 1 : 0);
      expect((media['frameRate'] as num).toDouble(), closeTo(15, 1));
      expect(source.existsSync(), isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  testWidgets('already-small input still produces a separate usable output', (
    tester,
  ) async {
    final info = await _compress(source.path);
    expect(info.path, isNot(source.path));
    expect(info.duration, closeTo(6000, 200));
    expect((await _inspect(info.path!))['audioTracks'], 1);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('progress stays finite and within the supported range', (
    tester,
  ) async {
    final progress = <double>[];
    final subscription = VideoCompress.compressProgress$.subscribe(
      progress.add,
    );
    try {
      await _compress(source.path, frameRate: 15);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // A very fast export need not emit an intermediate timer tick on iOS.
      for (final value in progress) {
        expect(value.isFinite, isTrue);
        expect(value, inInclusiveRange(0, 100));
      }
      if (Platform.isAndroid) expect(progress, contains(100.0));
    } finally {
      subscription.unsubscribe();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
    'cancel settles, prevents overlapping requests, and permits restart',
    (tester) async {
      final pending = VideoCompress.compressVideo(source.path, frameRate: 15);
      final rejected = expectLater(
        VideoCompress.compressVideo(source.path),
        throwsStateError,
      );
      // Queue cancellation before yielding to either platform response.
      final cancelling = VideoCompress.cancelCompression().timeout(_timeout);
      await rejected;
      await cancelling;
      expect(await pending.timeout(_timeout), isNull);
      expect(VideoCompress.isCompressing, isFalse);
      expect(VideoCompress.isCancel, isTrue);
      expect(source.existsSync(), isTrue);
      final restarted = await _compress(source.path, startTime: 1, duration: 1);
      expect(restarted.duration, closeTo(1000, 200));
      expect(VideoCompress.isCancel, isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets('native errors clear state and allow a subsequent compression', (
    tester,
  ) async {
    await expectLater(
      VideoCompress.compressVideo('${directory.path}/missing.mp4')
          .timeout(_timeout),
      throwsA(isA<PlatformException>()),
    );
    expect(VideoCompress.isCompressing, isFalse);
    await expectLater(
      VideoCompress.compressVideo(source.path, frameRate: 0).timeout(_timeout),
      throwsA(isA<PlatformException>()),
    );
    expect(VideoCompress.isCompressing, isFalse);
    await _compress(source.path, duration: 1);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('deleteOrigin deletes only the requested disposable input', (
    tester,
  ) async {
    final disposable = await source.copy('${directory.path}/disposable.mp4');
    await _compress(disposable.path, duration: 1, deleteOrigin: true);
    expect(disposable.existsSync(), isFalse);
    expect(source.existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
    'cache cleanup removes generated media and preserves the source',
    (tester) async {
      final thumbnail = await VideoCompress.getFileThumbnail(source.path)
          .timeout(_timeout);
      final output = await _compress(source.path);
      expect(await VideoCompress.deleteAllCache().timeout(_timeout), isTrue);
      expect(thumbnail.existsSync(), isFalse);
      expect(output.file!.existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
