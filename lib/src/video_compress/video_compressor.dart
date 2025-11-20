import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress_zero/src/progress_callback/compress_mixin.dart';
import 'package:video_compress_zero/video_compress_zero.dart';

abstract class IVideoCompress extends CompressMixin {
  Future<bool> requestPermission();
}

class _VideoCompressImpl extends IVideoCompress {
  _VideoCompressImpl._() {
    initProcessCallback();
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (status.isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.videos.isRestricted) {
        await Permission.videos.request();
      }
      return status.isGranted;
    }
    return true;
  }

  static _VideoCompressImpl? _instance;

  static _VideoCompressImpl get instance {
    return _instance ??= _VideoCompressImpl._();
  }

  static void _dispose() {
    _instance = null;
  }
}

// ignore: non_constant_identifier_names
IVideoCompress get VideoCompress => _VideoCompressImpl.instance;

extension Compress on IVideoCompress {
  void dispose() {
    _VideoCompressImpl._dispose();
  }

  // Returns true if the last compression was cancelled (iOS/macOS via events)
  bool get isCancel => wasCancelled;

  Future<T?> _invoke<T>(String name, [Map<String, dynamic>? params]) async {
    try {
      return params != null
          ? await channel.invokeMethod(name, params)
          : await channel.invokeMethod(name);
    } on PlatformException catch (e) {
      debugPrint('''Error from VideoCompress: 
      Method: $name
      $e''');
      rethrow;
    }
  }

  /// getByteThumbnail return [Future<Uint8List>],
  /// quality can be controlled by [quality] from 1 to 100,
  /// select the position unit in the video by [position] is milliseconds
  Future<Uint8List?> getByteThumbnail(
    String path, {
    int quality = 100,
    int position = -1,
  }) async {
    assert(quality >= 1 && quality <= 100);

    return await _invoke<Uint8List>('getByteThumbnail', {
      'path': path,
      'quality': quality,
      'position': position,
    });
  }

  /// getFileThumbnail return [Future<File>]
  /// quality can be controlled by [quality] from 1 to 100,
  /// select the position unit in the video by [position] is milliseconds
  Future<File> getFileThumbnail(
    String path, {
    int quality = 100,
    int position = -1,
  }) async {
    assert(quality >= 1 && quality <= 100);

    // Not to set the result as strong-mode so that it would have exception to
    // lead to the failure of compression
    final filePath = await (_invoke<String>('getFileThumbnail', {
      'path': path,
      'quality': quality,
      'position': position,
    }));

    final file = File(Uri.decodeFull(filePath!));

    return file;
  }

  /// get media information from [path]
  ///
  /// get media information from [path] return [Future<MediaInfo>]
  ///
  /// ## example
  /// ```dart
  /// final info = await _flutterVideoCompress.getMediaInfo(file.path);
  /// debugPrint(info.toJson());
  /// ```
  Future<MediaInfo> getMediaInfo(String path) async {
    // Not to set the result as strong-mode so that it would have exception to
    // lead to the failure of compression
    final jsonStr = await (_invoke<String>('getMediaInfo', {'path': path}));
    final jsonMap = json.decode(jsonStr!);
    return MediaInfo.fromJson(jsonMap);
  }

  /// compress video from [path]
  /// compress video from [path] return [Future<MediaInfo>]
  ///
  /// you can choose its quality by [quality],
  /// determine whether to delete his source file by [deleteOrigin]
  /// optional parameters [startTime] [duration] [includeAudio] [frameRate]
  ///
  /// ## example
  /// ```dart
  /// final info = await _flutterVideoCompress.compressVideo(
  ///   file.path,
  ///   deleteOrigin: true,
  /// );
  /// debugPrint(info.toJson());
  /// ```
  Future<MediaInfo?> compressVideo(
    String path, {
    VideoQuality quality = VideoQuality.DefaultQuality,
    bool deleteOrigin = false,
    int? startTime,
    int? duration,
    bool? includeAudio,
    int frameRate = 30,
  }) async {
    if (isCompressing) {
      throw StateError('''VideoCompress Error: 
      Method: compressVideo
      Already have a compression process, you need to wait for the process to finish or stop it''');
    }

    if (compressProgress$.notSubscribed) {
      debugPrint('''VideoCompress: You can try to subscribe to the 
      compressProgress\$ stream to know the compressing state.''');
    }

    // ignore: invalid_use_of_protected_member
    setProcessingStatus(true);
    // ignore: invalid_use_of_protected_member
    setCancelled(false); // reset cancel flag at start

    try {
      final jsonStr = await _invoke<String>('compressVideo', {
        'path': path,
        'quality': quality.index,
        'deleteOrigin': deleteOrigin,
        'startTime': startTime,
        'duration': duration,
        'includeAudio': includeAudio,
        'frameRate': frameRate,
      });

      // Don't clear processing status here on iOS - let events handle it
      // On Android, clear it since method returns when done
      if (Platform.isAndroid) {
        // ignore: invalid_use_of_protected_member
        setProcessingStatus(false);
      }

      if (jsonStr != null) {
        final jsonMap = json.decode(jsonStr);
        return MediaInfo.fromJson(jsonMap);
      } else {
        return null;
      }
    } catch (e) {
      // On error, always clear the flag
      // ignore: invalid_use_of_protected_member
      setProcessingStatus(false);
      rethrow;
    }
  }

  /// stop compressing the file that is currently being compressed.
  /// If there is no compression process, nothing will happen.
  Future<void> cancelCompression() async {
    await _invoke<void>('cancelCompression');
    // Clear the compressing state immediately
    // ignore: invalid_use_of_protected_member
    setProcessingStatus(false);
    // ignore: invalid_use_of_protected_member
    setCancelled(true); // reflect cancellation immediately
  }

  /// delete the cache folder, please do not put other things
  /// in the folder of this plugin, it will be cleared
  Future<bool?> deleteAllCache() async {
    return await _invoke<bool>('deleteAllCache');
  }

  Future<void> setLogLevel(int logLevel) async {
    return await _invoke<void>('setLogLevel', {
      'logLevel': logLevel,
    });
  }
}
