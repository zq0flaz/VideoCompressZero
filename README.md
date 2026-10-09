# video_compress_zero

> ✅ This package is a **fork** of the original [`video_compress`]
(https://github.com/jonataslaw/VideoCompress), original pub dev (https://pub.dev/packages/video_compress) (version 3.1.4).

---

## ⚠️ Status: Experimental

> **Note:** This package has not been fully tested on all platforms yet. Please use with caution and report any issues found.

🚧 iOS: Not tested
macOS is currently unsupported; the repository does not contain a native macOS plugin.

---

## 🔧 What's Different from the Original?

This fork was created to:
- ✅ Support **Android API Level 35 (Android 15)**
- ✅ Ensure compatibility with **Gradle 8.0+**
- 🔧 Fix permission issues during the Android manifest merge

# video_compress

Compress videos, remove audio, manipulate thumbnails, and make your video compatible with all platforms through this lightweight and efficient library.
100% native code was used, we do not use FFMPEG as it is very slow, bloated and the GNU license is an obstacle for commercial applications.
In addition, google chrome uses VP8/VP9, safari uses h264, and most of the time, it is necessary to encode the video in two formats, but not with this library.
All video files are encoded in an MP4 container with AAC audio that allows 100% compatibility with safari, mozila, chrome, android and iOS.

Works on Android and iOS. iOS requires iOS 13 or newer and supports CocoaPods and Swift Package Manager packaging.



# Table of Contents
  - [Installing](#lets-get-started)
  - [How to use](#how-to-use)
    * [Imports](#imports)
    * [Video compression](#video-compression)
    * [Check compress state](#check-compress-state)
    * [Get memory thumbnail from VideoPath](#get-memory-thumbnail-from-videopath)
    * [Get File thumbnail from VideoPath](#get-file-thumbnail-from-videopath)
    * [Get media information](#get-media-information)
    * [delete all cache files](#delete-all-cache-files)
    * [Listen the compression progress](#listen-the-compression-progress)
  - [TODO](#todo)

# Lets Get Started

### 1. Depend on it
Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  video_compress_zero: 3.1.4+202507
```

### 2. Install it

You can install packages from the command line:

with `pub`:

```css
$  pub get
```

### 3. Import it

Now in your `Dart` code, you can use: 

````dart
import 'package:video_compress_zero/video_compress_zero.dart';
````

# How to use

## iOS UIScene support

The iOS plugin registers its method and event channels through the Flutter engine
registrar and does not depend on application UI lifecycle callbacks. It can be
used in a UIScene host app without adding scene callbacks to the plugin.

UIScene adoption is configured in the **host app**, so updating this package alone
does not migrate an existing app. With Flutter 3.38 or newer (3.41+ recommended):

1. Make your host `AppDelegate` conform to `FlutterImplicitEngineDelegate` and
   register plugins in `didInitializeImplicitFlutterEngine`, using
   `engineBridge.pluginRegistry`, instead of `didFinishLaunchingWithOptions`.
2. Add `UIApplicationSceneManifest` to the host's `ios/Runner/Info.plist`, using
   `FlutterSceneDelegate`, `UIWindowScene`, and your `Main` storyboard. Keep
   `UIApplicationSupportsMultipleScenes` set to `false` for a single-window app.
3. Move any custom UI lifecycle callbacks to a subclass of `FlutterSceneDelegate`
   if your app needs them.

The [example AppDelegate](example/ios/Runner/AppDelegate.swift) and
[Info.plist](example/ios/Runner/Info.plist) demonstrate this configuration. Only
the example requires Flutter 3.38+; the plugin keeps its existing SDK minimum.
See the [Flutter UIScene migration guide](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
for custom host integrations.

On macOS, validate with `cd example` and `flutter build ios --simulator`, then run
the example on an iOS simulator or device. Check cold launch, thumbnail creation,
compression progress/completion, cancellation, and background/foreground transitions.
UIScene adoption does not itself grant background execution time for compression.

### Native regression tests

Run `flutter test` and `flutter analyze` from the repository root. For Android,
build the example with `flutter build apk --release`, then run
`./gradlew :video_compress_zero:testDebugUnitTest` from `example/android` (use
`gradlew.bat` on Windows).

On macOS, disable SwiftPM for the CocoaPods test host with
`flutter config --no-enable-swift-package-manager`, run `flutter pub get` in
`example`, then run `ruby scripts_setup_ios_tests.rb` from the repository root.
This adds the RunnerTests target and enables it in the Runner scheme. Build the
example with `flutter build ios --simulator`, then run its Runner tests in Xcode.
The tests cover cancellation/restart, invalid input, path decoding, thumbnail
timing/orientation, and trimmed exports using a generated video fixture.

CI also builds a separate host with SwiftPM enabled on the stable Flutter channel.
The Swift sources live in `ios/video_compress_zero/Sources/video_compress_zero`;
both the podspec and SwiftPM manifest use this directory.

### Imports

````dart
import 'package:video_compress_zero/video_compress_zero.dart';
    
````

## Video compression

```dart
MediaInfo mediaInfo = await VideoCompress.compressVideo(
  path,
  quality: VideoQuality.DefaultQuality, 
  deleteOrigin: false, // It's false by default
);
```

## Check compress state
```dart
VideoCompress.isCompressing
```
<!-- ## Cancel compression
```dart
await videoCompress.cancelCompression()
``` -->

## Get memory thumbnail from VideoPath
```dart
final uint8list = await VideoCompress.getByteThumbnail(
  videopath,
  quality: 50, // default(100)
  position: -1 // default(-1)
);
```

## Get File thumbnail from VideoPath
```dart
final thumbnailFile = await VideoCompress.getFileThumbnail(
  videopath,
  quality: 50, // default(100)
  position: -1 // default(-1)
);
```

## Get media information

```dart
final info = await VideoCompress.getMediaInfo(videopath);

```

## delete all cache files
- Delete all files generated by this will delete all files located at 'video_compress', you shoule ought to know what are you doing.

```dart
await VideoCompress.deleteAllCache()
```

## Listen the compression progress
```dart
class _Compress extends State<Compress> {

  Subscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        VideoCompress.compressProgress$.subscribe((progress) {
      debugPrint('progress: $progress');
    });
  }

  @override
  void dispose() {
    super.dispose();
    _subscription.unsubscribe();
  }
}
```

### TODO
- Add the trim video function
- Add cancel function to Android

## Methods
| Functions         | Parameters                                                                                                                                                                                                                                                                                                                                    | Description                                                                                      | Returns             |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------- |
| getByteThumbnail  | String `path`[video path], int `quality`(1-100)[thumbnail quality], int `position`[Get a thumbnail from video position]                                                                                                                                                                                                                       | get thumbnail from video `path`                                                                  | `Future<Uint8List>` |
| getFileThumbnail  | String `path`[video path], int `quality`(1-100)[thumbnail quality], int `position`[Get a thumbnail from video position]                                                                                                                                                                                                                       | get thumbnail file from video `path`                                                             | `Future<File>`      |
| getMediaInfo      | String `path`[video path]                                                                                                                                                                                                                                                                                                                     | get media information from video `path`                                                          | `Future<MediaInfo>` |
| compressVideo     | String `path`[video path], VideoQuality `quality`[compressed video quality], bool `deleteOrigin`[delete the origin video], int `startTime`[compression video start time], int `duration`[compression video duration from start time], bool `includeAudio`[is include audio in compressed video], int `frameRate`[compressed video frame rate] | compression video at origin video `path`                                                         | `Future<MediaInfo>` |
| cancelCompression | `none`                                                                                                                                                                                                                                                                                                                                        | cancel compressing                                                                               | `Future<void>`      |
| deleteAllCache    | `none`                                                                                                                                                                                                                                                                                                                                        | Delete all files generated by 'video_compress' will delete all files located at 'video_compress' | `Future<bool>`      |

## Subscriptions
| Subscriptions     | Description                              | Stream            |
| ----------------- | ---------------------------------------- | ----------------- |
| compressProgress$ | Subscribe the compression progress steam | double `progress` |

## Contribute

Contributions are always welcome!
<!-- Please read the [contribution guidelines](contributing.md) first. -->

## acknowledgment

Inspired by the flutter_ffmpeg library.
https://github.com/rurico/flutter_video_compress

