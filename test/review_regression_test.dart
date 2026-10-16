import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress_zero/video_compress_zero.dart';
import 'package:video_compress_zero/src/video_compress/android_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('video_compress_zero');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

  tearDown(() {
    VideoCompress.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(permissions, null);
  });

  test('thumbnail raw paths preserve literal percent escapes', () async {
    messenger.setMockMethodCallHandler(
        channel, (_) async => '/tmp/literal%20name.jpg');
    final file = await VideoCompress.getFileThumbnail('/mock.mp4');
    expect(file.path, '/tmp/literal%20name.jpg');
    messenger.setMockMethodCallHandler(
        channel, (_) async => 'file:///tmp/a%20b.jpg');
    expect((await VideoCompress.getFileThumbnail('/mock.mp4')).path,
        '/tmp/a b.jpg');
  });

  test('remaining subscribers stay visible and disposal ends stream', () async {
    final observable = ObservableBuilder<int>();
    final first = observable.subscribe((_) {});
    final done = Completer<void>();
    observable.subscribe((_) {}, onDone: done.complete);
    first.unsubscribe();
    expect(observable.notSubscribed, isFalse);
    observable.close();
    await done.future;
    observable.next(1); // late native progress must not throw after close
  });

  test('cancel waits for terminal response and prevents restart/disposal',
      () async {
    final pending = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'compressVideo') return pending.future;
      return null;
    });
    final compression = VideoCompress.compressVideo('/mock.mp4');
    var cancelled = false;
    final cancellation =
        VideoCompress.cancelCompression().then((_) => cancelled = true);
    await Future<void>.delayed(Duration.zero);
    expect(VideoCompress.isCompressing, isTrue);
    expect(cancelled, isFalse);
    expect(() => VideoCompress.dispose(), throwsStateError);
    await expectLater(
        VideoCompress.compressVideo('/second.mp4'), throwsStateError);
    pending.complete(null);
    await compression;
    await cancellation;
    expect(VideoCompress.isCompressing, isFalse);
    expect(VideoCompress.isCancel, isTrue);
  });

  for (final sdk in [32, 33, 34]) {
    test('Android $sdk requests the correct permission and returns new grant',
        () async {
      final expected = sdk >= 33 ? Permission.videos : Permission.storage;
      messenger.setMockMethodCallHandler(permissions, (call) async {
        if (call.method == 'checkPermissionStatus') {
          expect(call.arguments, expected.value);
          return PermissionStatus.denied.index;
        }
        expect(call.method, 'requestPermissions');
        expect(call.arguments, [expected.value]);
        return {expected.value: PermissionStatus.granted.index};
      });
      expect(await requestAndroidVideoPermission(sdk), isTrue);
    });
  }

  test('permanently denied access does not prompt repeatedly', () async {
    messenger.setMockMethodCallHandler(permissions, (call) async {
      expect(call.method, 'checkPermissionStatus');
      return PermissionStatus.permanentlyDenied.index;
    });
    expect(await requestAndroidVideoPermission(34), isFalse);
  });

  test('Android limited video access is usable', () async {
    messenger.setMockMethodCallHandler(
        permissions, (_) async => PermissionStatus.limited.index);
    expect(await requestAndroidVideoPermission(34), isTrue);
  });
}
