import 'package:flutter/foundation.dart';
import 'package:video_compress_zero/video_compress_zero.dart';

enum CompressionPhase {
  idle,
  picking,
  ready,
  compressing,
  cancelling,
  completed,
  cancelled,
  failed,
  saving
}

/// Keeps asynchronous results from updating a disposed or superseded screen.
class CompressionController extends ChangeNotifier {
  CompressionController(
      {required this.pickVideo,
      required this.readInfo,
      required this.compress,
      required this.cancel,
      required this.save});

  final Future<String?> Function() pickVideo;
  final Future<MediaInfo> Function(String) readInfo;
  final Future<MediaInfo?> Function(String, VideoQuality, int, bool) compress;
  final Future<void> Function() cancel;
  final Future<void> Function(String) save;

  CompressionPhase phase = CompressionPhase.idle;
  String message = 'Select a video to begin';
  String? path;
  MediaInfo? original;
  MediaInfo? result;
  double progress = 0;
  Duration? elapsed;
  VideoQuality quality = VideoQuality.Res960x540Quality;
  int frameRate = 30;
  bool includeAudio = true;
  bool _disposed = false;
  int _generation = 0;

  bool get busy => {
        CompressionPhase.picking,
        CompressionPhase.compressing,
        CompressionPhase.cancelling,
        CompressionPhase.saving
      }.contains(phase);
  bool _current(int generation) => !_disposed && generation == _generation;

  void updateProgress(double value) {
    if (_disposed || phase != CompressionPhase.compressing || !value.isFinite) {
      return;
    }
    progress = value.clamp(0, 100);
    notifyListeners();
  }

  Future<void> pick() async {
    if (busy) return;
    final generation = ++_generation;
    phase = CompressionPhase.picking;
    message = 'Selecting video…';
    notifyListeners();
    try {
      final selected = await pickVideo();
      if (!_current(generation)) return;
      if (selected == null) {
        phase = result != null
            ? CompressionPhase.completed
            : path != null
                ? CompressionPhase.ready
                : CompressionPhase.idle;
        message = 'Selection cancelled';
      } else {
        // Clear the previous selection before loading metadata.
        path = null;
        original = null;
        result = null;
        elapsed = null;
        progress = 0;
        message = 'Reading video information…';
        notifyListeners();
        final info = await readInfo(selected);
        if (!_current(generation)) return;
        path = selected;
        original = info;
        phase = CompressionPhase.ready;
        message = 'Ready to compress';
      }
    } catch (_) {
      if (!_current(generation)) return;
      phase = CompressionPhase.failed;
      message =
          'Could not open this video. Check access or choose another file.';
    }
    if (_current(generation)) notifyListeners();
  }

  Future<void> start() async {
    if (busy || path == null) return;
    final generation = ++_generation;
    final timer = Stopwatch()..start();
    phase = CompressionPhase.compressing;
    message = 'Compressing…';
    progress = 0;
    result = null;
    elapsed = null;
    notifyListeners();
    try {
      final info = await compress(path!, quality, frameRate, includeAudio);
      if (!_current(generation)) return;
      final cancelled =
          phase == CompressionPhase.cancelling || info?.isCancel == true;
      if (cancelled) {
        phase = CompressionPhase.cancelled;
        progress = 0;
        message = 'Compression cancelled';
      } else if (info == null || (info.path?.isEmpty ?? true)) {
        phase = CompressionPhase.failed;
        message = 'No output video was produced. Try another video or quality.';
      } else {
        result = info;
        phase = CompressionPhase.completed;
        progress = 100;
        message = 'Compression completed';
      }
    } catch (_) {
      if (!_current(generation)) return;
      final cancelled = phase == CompressionPhase.cancelling;
      phase = cancelled ? CompressionPhase.cancelled : CompressionPhase.failed;
      progress = 0;
      message = cancelled
          ? 'Compression cancelled'
          : 'Compression failed. Try another video or quality.';
    } finally {
      timer.stop();
      if (_current(generation)) {
        elapsed = timer.elapsed;
        notifyListeners();
      }
    }
  }

  Future<void> requestCancel() async {
    if (phase != CompressionPhase.compressing) return;
    final generation = _generation;
    phase = CompressionPhase.cancelling;
    message = 'Cancelling compression…';
    notifyListeners();
    try {
      await cancel();
      // Remain busy until the compression future reaches its terminal state.
    } catch (_) {
      if (!_current(generation) || phase != CompressionPhase.cancelling) return;
      phase = CompressionPhase.compressing;
      message = 'Could not cancel. Compression is still running.';
      notifyListeners();
    }
  }

  Future<void> saveResult() async {
    final output = result?.path;
    if (busy || output == null) return;
    final generation = ++_generation;
    phase = CompressionPhase.saving;
    message = 'Saving to gallery…';
    notifyListeners();
    try {
      await save(output);
      if (!_current(generation)) return;
      message = 'Saved to your gallery';
    } catch (_) {
      if (!_current(generation)) return;
      message =
          'Could not save video. Check photo library permission and available storage, then retry.';
    }
    if (_current(generation)) {
      phase = CompressionPhase.completed;
      notifyListeners();
    }
  }

  void reset() {
    if (busy || _disposed) return;
    ++_generation;
    path = null;
    original = null;
    result = null;
    elapsed = null;
    progress = 0;
    phase = CompressionPhase.idle;
    message = 'Select a video to begin';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}

String formatSize(int? bytes) => bytes == null || bytes < 0
    ? 'Unavailable'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
String formatDuration(double? milliseconds) =>
    milliseconds == null || !milliseconds.isFinite || milliseconds < 0
        ? 'Unavailable'
        : '${(milliseconds / 1000).toStringAsFixed(2)} s';
String sizeChange(int? before, int? after) {
  if (before == null || before <= 0 || after == null || after < 0) {
    return 'Unavailable';
  }
  final change = (before - after) / before * 100;
  return '${change.abs().toStringAsFixed(1)}% ${change >= 0 ? 'smaller' : 'larger'}';
}
