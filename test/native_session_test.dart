import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress_zero/src/progress_callback/compress_mixin.dart';

class TestSession extends CompressMixin {
  void start() => initProcessCallback();
  void close() => disposeProcessCallback();
  int beginRequest() {
    setProcessingStatus(true);
    return processingGeneration;
  }

  void completeRequest(int generation) =>
      setProcessingStatus(false, generation: generation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const events = 'video_compress_zero/events';
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('an old request reply cannot clear a new request state', () {
    final session = TestSession();
    final first = session.beginRequest();
    session.completeRequest(first);
    final second = session.beginRequest();
    session.completeRequest(first);
    expect(session.isCompressing, isTrue);
    session.completeRequest(second);
    expect(session.isCompressing, isFalse);
  });

  test('late cancellation and progress cannot change a new session', () async {
    messenger.setMockMethodCallHandler(
        const MethodChannel(events), (_) async => null);
    final session = TestSession()..start();
    await Future<void>.delayed(Duration.zero);
    Future<void> emit(String type, String id) async {
      await messenger.handlePlatformMessage(
          events,
          codec.encodeSuccessEnvelope(
              {'type': type, 'sessionId': id, 'progress': 50.0}),
          (_) {});
      await Future<void>.delayed(Duration.zero);
    }

    await emit('started', 'A');
    await emit('cancelled', 'A');
    expect(session.wasCancelled, isTrue);
    await emit('started', 'B');
    await emit('cancelled', 'A');
    expect(session.isCompressing, isTrue);
    expect(session.wasCancelled, isFalse);
    await emit('completed', 'B');
    expect(session.isCompressing, isFalse);
    session.close();
    messenger.setMockMethodCallHandler(const MethodChannel(events), null);
  });
}
