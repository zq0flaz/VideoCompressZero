import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'subscription.dart';

class CompressMixin {
  final compressProgress$ = ObservableBuilder<double>();
  // Unified MethodChannel name after migration to video_compress_zero on all platforms
  final _channel = const MethodChannel('video_compress_zero');
  // Event channel for iOS plugin events (Android currently not emitting events)
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

  MethodChannel get channel => _channel;

  bool _isCompressing = false;
  bool _wasCancelled = false; // last known cancellation state from native
  String? _activeSessionId;
  int _processingGeneration = 0;

  @protected
  int get processingGeneration => _processingGeneration;

  bool get isCompressing => _isCompressing;
  bool get wasCancelled => _wasCancelled;

  // Allow API layer to update cancellation flag when appropriate
  @protected
  void setCancelled(bool value) {
    _wasCancelled = value;
  }

  @protected
  void setProcessingStatus(bool status, {int? generation}) {
    if (generation != null && generation != _processingGeneration) return;
    if (status) _processingGeneration++;
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
      debugPrint('🔵 Event received: $event');
      if (event is Map) {
        final type = event['type'];
        final sessionId = event['sessionId'] as String?;
        if (type == 'started') {
          _activeSessionId = sessionId;
        } else if (sessionId != null && sessionId != _activeSessionId) {
          return;
        }
        debugPrint('🔵 Event type: $type');
        switch (type) {
          case 'progress':
            final p = event['progress'];
            debugPrint('🔵 Progress value: $p');
            if (p != null) compressProgress$.next((p as num).toDouble());
            break;
          case 'started':
            debugPrint('compression started: ${event['sessionId']}');
            // Ensure compressing status is set (iOS state now active)
            if (!_isCompressing) {
              _isCompressing = true;
            }
            _wasCancelled = false;
            break;
          case 'completed':
            _activeSessionId = null;
            debugPrint('compression completed: ${event['sessionId']}');
            // Clear compressing status when iOS confirms completion
            _isCompressing = false;
            _wasCancelled = false;
            break;
          case 'cancelled':
            _activeSessionId = null;
            debugPrint('compression cancelled: ${event['sessionId']}');
            // Clear compressing status when iOS confirms cancellation
            _isCompressing = false;
            _wasCancelled = true;
            break;
          case 'failed':
            _activeSessionId = null;
            debugPrint(
                'compression failed: ${event['sessionId']} - ${event['error']}');
            // Clear compressing status when iOS confirms failure
            _isCompressing = false;
            _wasCancelled = false;
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
