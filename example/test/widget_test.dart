import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress_zero/video_compress_zero.dart';
import 'package:video_compress_zero_example/compression_controller.dart';
import 'package:video_compress_zero_example/main.dart';

void main() {
  late CompressionController controller;
  late Completer<MediaInfo?> compression;
  late Completer<void> cancellation;
  late List<String> saved;

  setUp(() {
    compression = Completer<MediaInfo?>();
    cancellation = Completer<void>();
    saved = [];
    controller = CompressionController(
      pickVideo: () async => '/mock/input.mp4',
      readInfo: (path) async => MediaInfo(path: path, filesize: 1000),
      compress: (path, quality, fps, audio) => compression.future,
      cancel: () => cancellation.future,
      save: (path) async => saved.add(path),
    );
  });
  tearDown(() => controller.dispose());

  test('successful compression exposes output and saves it', () async {
    await controller.pick();
    final running = controller.start();
    controller.updateProgress(125);
    expect(controller.progress, 100);
    compression.complete(MediaInfo(path: '/mock/output.mp4', filesize: 500));
    await running;
    expect(controller.phase, CompressionPhase.completed);
    expect(controller.elapsed, isNotNull);
    await controller.saveResult();
    expect(saved, ['/mock/output.mp4']);
    expect(controller.message, 'Saved to your gallery');
  });

  test('cancel acknowledgement keeps operations locked until completion',
      () async {
    await controller.pick();
    final running = controller.start();
    final cancelling = controller.requestCancel();
    cancellation.complete();
    await cancelling;
    expect(controller.busy, isTrue);
    controller.reset();
    await controller.pick();
    expect(controller.path, '/mock/input.mp4');
    expect(controller.phase, CompressionPhase.cancelling);
    compression.complete(null);
    await running;
    expect(controller.phase, CompressionPhase.cancelled);
    expect(controller.result, isNull);
  });

  test('missing output is a recoverable failure', () async {
    await controller.pick();
    final running = controller.start();
    compression.complete(null);
    await running;
    expect(controller.phase, CompressionPhase.failed);
    expect(controller.busy, isFalse);
    controller.reset();
    expect(controller.path, isNull);
  });

  test('late completion after disposal does not notify listeners', () async {
    await controller.pick();
    final running = controller.start();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.dispose();
    compression.complete(MediaInfo(path: '/mock/output.mp4'));
    await running;
    expect(notifications, 0);
    // Give tearDown a separate live instance.
    controller = CompressionController(
        pickVideo: () async => null,
        readInfo: (p) async => MediaInfo(path: p),
        compress: (p, q, f, a) async => null,
        cancel: () async {},
        save: (p) async {});
  });

  test('invalid media and denied gallery access produce actionable errors',
      () async {
    final invalid = CompressionController(
        pickVideo: () async => '/invalid.mp4',
        readInfo: (_) async => throw StateError('invalid media'),
        compress: (p, q, f, a) async => null,
        cancel: () async {},
        save: (p) async {});
    await invalid.pick();
    expect(invalid.phase, CompressionPhase.failed);
    expect(invalid.path, isNull);
    invalid.dispose();
    final denied = CompressionController(
        pickVideo: () async => '/input.mp4',
        readInfo: (p) async => MediaInfo(path: p),
        compress: (p, q, f, a) async => MediaInfo(path: '/output.mp4'),
        cancel: () async {},
        save: (_) async => throw StateError('permission denied'));
    await denied.pick();
    await denied.start();
    await denied.saveResult();
    expect(denied.message, contains('permission'));
    expect(denied.result, isNotNull);
    expect(denied.busy, isFalse);
    denied.dispose();
  });

  test('metadata formatting handles missing, zero and larger outputs', () {
    expect(formatSize(null), 'Unavailable');
    expect(formatDuration(double.nan), 'Unavailable');
    expect(sizeChange(0, 10), 'Unavailable');
    expect(sizeChange(100, 150), '50.0% larger');
    expect(sizeChange(100, 50), '50.0% smaller');
  });

  testWidgets('home requires a selection before compression', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Select a video to begin'), findsOneWidget);
    final start = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start Compression'));
    expect(start.onPressed, isNull);
    expect(find.text('Save to Gallery'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
