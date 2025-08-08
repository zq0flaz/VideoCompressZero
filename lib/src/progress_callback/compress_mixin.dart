import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'subscription.dart';

class CompressMixin {
  final compressProgress$ = ObservableBuilder<double>();
  final _channel = const MethodChannel('video_compress');
  final _channelZero = const MethodChannel('video_compress_zero');

  @protected
  void initProcessCallback() {
    channel.setMethodCallHandler(_progressCallback);
  }

  MethodChannel get channel => Platform.isAndroid ? _channel : _channelZero;

  bool _isCompressing = false;

  bool get isCompressing => _isCompressing;

  @protected
  void setProcessingStatus(bool status) {
    _isCompressing = status;
  }

  Future<void> _progressCallback(MethodCall call) async {
    switch (call.method) {
      case 'updateProgress':
        debugPrint('updateProgress: ${call.arguments}');
        final progress = double.tryParse(call.arguments.toString());
        if (progress != null) compressProgress$.next(progress);
        break;
    }
  }
}
