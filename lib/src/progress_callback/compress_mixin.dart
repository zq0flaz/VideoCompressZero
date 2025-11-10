import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'subscription.dart';

class CompressMixin {
  final compressProgress$ = ObservableBuilder<double>();
  final _channel = const MethodChannel('video_compress');
  final _channelZero = const MethodChannel('video_compress_zero');
  // Event channel for iOS plugin events
  final _eventChannelZero = const EventChannel('video_compress_zero/events');
  StreamSubscription? _eventSub;

  @protected
  void initProcessCallback() {
    channel.setMethodCallHandler(_progressCallback);
    // Listen to iOS EventChannel for structured events
    if (!Platform.isAndroid) {
      _eventSub = _eventChannelZero.receiveBroadcastStream().listen((event) {
        _handleEvent(event);
      }, onError: (err) {
        debugPrint('EventChannel error: $err');
      });
    }
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

  void _handleEvent(dynamic event) {
    try {
      if (event is Map) {
        final type = event['type'];
        switch (type) {
          case 'progress':
            final p = event['progress'];
            if (p != null) compressProgress$.next((p as num).toDouble());
            break;
          case 'started':
            debugPrint('compression started: ${event['sessionId']}');
            // Ensure compressing status is set (iOS state now active)
            if (!_isCompressing) {
              _isCompressing = true;
            }
            break;
          case 'completed':
            debugPrint('compression completed: ${event['sessionId']}');
            // Clear compressing status when iOS confirms completion
            _isCompressing = false;
            break;
          case 'cancelled':
            debugPrint('compression cancelled: ${event['sessionId']}');
            // Clear compressing status when iOS confirms cancellation
            _isCompressing = false;
            break;
          case 'failed':
            debugPrint(
                'compression failed: ${event['sessionId']} - ${event['error']}');
            // Clear compressing status when iOS confirms failure
            _isCompressing = false;
            break;
        }
      }
    } catch (e) {
      debugPrint('Error handling event: $e');
    }
  }

  @protected
  void disposeProcessCallback() {
    _eventSub?.cancel();
    _eventSub = null;
  }
}
