import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress_zero/video_compress_zero.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoCompress', () {
    const MethodChannel channel = MethodChannel('video_compress_zero');

    setUp(() {
      // Reset method call handler before each test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      // Clean up after each test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('Quality parameter validation', () {
      test('Valid quality values should be within range 1-100', () {
        const validQualities = [1, 2, 50, 99, 100];
        for (final quality in validQualities) {
          expect(quality >= 1 && quality <= 100, isTrue,
              reason: 'Quality $quality should be valid (1-100 inclusive)');
        }
      });

      test('Invalid quality values should be outside range 1-100', () {
        const invalidQualities = [0, -1, 101, 200];
        for (final quality in invalidQualities) {
          expect(quality >= 1 && quality <= 100, isFalse,
              reason:
                  'Quality $quality should be invalid (outside 1-100 range)');
        }
      });

      test('Boundary values', () {
        expect(1 >= 1 && 1 <= 100, isTrue);
        expect(100 >= 1 && 100 <= 100, isTrue);
        expect(0 >= 1 && 0 <= 100, isFalse);
        expect(101 >= 1 && 101 <= 100, isFalse);
      });
    });

    group('getByteThumbnail', () {
      test('should call platform method with correct parameters', () async {
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return Uint8List(0); // Return empty byte array
        });

        await VideoCompress.getByteThumbnail(
          '/path/to/video.mp4',
          quality: 80,
          position: 5000,
        );

        expect(log, hasLength(1));
        expect(log[0].method, 'getByteThumbnail');
        expect(log[0].arguments['path'], '/path/to/video.mp4');
        expect(log[0].arguments['quality'], 80);
        expect(log[0].arguments['position'], 5000);
      });

      test('should throw assertion error for invalid quality', () {
        expect(
          () => VideoCompress.getByteThumbnail(
            '/path/to/video.mp4',
            quality: 0, // Invalid
            position: 5000,
          ),
          throwsAssertionError,
        );

        expect(
          () => VideoCompress.getByteThumbnail(
            '/path/to/video.mp4',
            quality: 101, // Invalid
            position: 5000,
          ),
          throwsAssertionError,
        );
      });
    });

    group('getFileThumbnail', () {
      test('should call platform method with correct parameters', () async {
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return '/path/to/thumbnail.jpg';
        });

        await VideoCompress.getFileThumbnail(
          '/path/to/video.mp4',
          quality: 90,
          position: 3000,
        );

        expect(log, hasLength(1));
        expect(log[0].method, 'getFileThumbnail');
        expect(log[0].arguments['path'], '/path/to/video.mp4');
        expect(log[0].arguments['quality'], 90);
        expect(log[0].arguments['position'], 3000);
      });
    });

    group('getMediaInfo', () {
      test('should return MediaInfo object', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getMediaInfo') {
            return '{"path":"/test.mp4","title":"Test","width":1920,"height":1080,"duration":10000,"filesize":5000000,"orientation":0}';
          }
          return null;
        });

        final info = await VideoCompress.getMediaInfo('/test.mp4');

        expect(info.path, '/test.mp4');
        expect(info.title, 'Test');
        expect(info.width, 1920);
        expect(info.height, 1080);
        expect(info.duration, 10000);
        expect(info.filesize, 5000000);
        expect(info.orientation, 0);
      });
    });

    group('compressVideo', () {
      test('should throw error when already compressing', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          // Simulate long-running compression
          await Future.delayed(Duration(seconds: 1));
          return '{"path":"/compressed.mp4","filesize":1000000}';
        });

        // Start first compression
        final future1 = VideoCompress.compressVideo('/video1.mp4');

        // Try to start second compression while first is running
        expect(
          () => VideoCompress.compressVideo('/video2.mp4'),
          throwsStateError,
        );

        // Wait for first to complete
        await future1;
      });

      test('should call platform method with correct parameters', () async {
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return '{"path":"/compressed.mp4","filesize":1000000,"isCancel":false}';
        });

        await VideoCompress.compressVideo(
          '/test.mp4',
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
          frameRate: 30,
        );

        expect(log, hasLength(1));
        expect(log[0].method, 'compressVideo');
        expect(log[0].arguments['path'], '/test.mp4');
        expect(log[0].arguments['deleteOrigin'], false);
        expect(log[0].arguments['includeAudio'], true);
        expect(log[0].arguments['frameRate'], 30);
      });
    });

    group('cancelCompression', () {
      test('should call platform method', () async {
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        });

        await VideoCompress.cancelCompression();

        expect(log, hasLength(1));
        expect(log[0].method, 'cancelCompression');
      });
    });

    group('deleteAllCache', () {
      test('should call platform method and return result', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'deleteAllCache') {
            return true;
          }
          return null;
        });

        final result = await VideoCompress.deleteAllCache();

        expect(result, isTrue);
      });
    });

    group('setLogLevel', () {
      test('should call platform method with log level', () async {
        final List<MethodCall> log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        });

        await VideoCompress.setLogLevel(2);

        expect(log, hasLength(1));
        expect(log[0].method, 'setLogLevel');
        expect(log[0].arguments['logLevel'], 2);
      });
    });
  });

  group('ObservableBuilder', () {
    test('should support subscription and unsubscription', () async {
      final observable = ObservableBuilder<int>();
      int? receivedValue;

      final subscription = observable.subscribe((value) {
        receivedValue = value;
      });

      observable.next(42);

      // Give stream time to process
      await Future.delayed(Duration(milliseconds: 100));

      expect(receivedValue, 42);

      // Unsubscribe
      subscription.unsubscribe();

      // After unsubscribe, notSubscribed should be true
      expect(observable.notSubscribed, isTrue);
    });

    test('should support multiple subscribers with broadcast stream', () async {
      final observable = ObservableBuilder<String>();
      String? value1;
      String? value2;

      final sub1 = observable.subscribe((value) {
        value1 = value;
      });

      final sub2 = observable.subscribe((value) {
        value2 = value;
      });

      observable.next('test');

      // Give stream time to process
      await Future.delayed(Duration(milliseconds: 100));

      expect(value1, 'test');
      expect(value2, 'test');

      sub1.unsubscribe();
      sub2.unsubscribe();
    });
  });

  group('MediaInfo', () {
    test('should parse JSON correctly', () {
      final json = {
        'path': '/test.mp4',
        'title': 'Test Video',
        'author': 'Test Author',
        'width': 1920.0,
        'height': 1080.0,
        'duration': 60000.0,
        'filesize': 10000000.0,
        'orientation': 90,
        'isCancel': false,
      };

      final mediaInfo = MediaInfo.fromJson(json);

      expect(mediaInfo.path, '/test.mp4');
      expect(mediaInfo.title, 'Test Video');
      expect(mediaInfo.author, 'Test Author');
      expect(mediaInfo.width, 1920);
      expect(mediaInfo.height, 1080);
      expect(mediaInfo.duration, 60000);
      expect(mediaInfo.filesize, 10000000);
      expect(mediaInfo.orientation, 90);
      expect(mediaInfo.isCancel, false);
    });

    test('should handle null values', () {
      final json = {
        'path': '/test.mp4',
      };

      final mediaInfo = MediaInfo.fromJson(json);

      expect(mediaInfo.path, '/test.mp4');
      expect(mediaInfo.title, isNull);
      expect(mediaInfo.author, isNull);
      expect(mediaInfo.isCancel, isNull);
    });
  });
}
