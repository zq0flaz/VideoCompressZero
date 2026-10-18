# Native integration tests

These tests call the actual Android/iOS compression plugin through its method
and event channels. They do not mock the encoder or invoke photo pickers,
permission dialogs, gallery saves, or network services.

## Automatic CI

`.github/workflows/native-integration.yml` runs on pushes to master and the
Flutter compatibility branch, pull requests to master, and manual dispatch:

| Target | Configuration |
| --- | --- |
| Android emulator | API 29 and 35, x86_64, Google APIs, JDK 17 |
| iOS simulator | Available iPhone runtime on macos-latest, SwiftPM |
| Flutter | 3.47.7, matching the compatibility matrix's upper version |

The existing compatibility workflow separately builds CocoaPods consumers and
tests Dart/JVM code across Flutter 3.41–3.47. iOS runtime integration tests use
the committed SwiftPM example. This does not run the separate local XCTest suite.

Failures return a nonzero exit code. CI uploads Flutter output, runner status,
and Android emulator logcat under the `integration-*` artifacts even on failure.
No excluded/local AI setup scripts are required.

## Run locally

Install the Flutter SDK pinned in `.fvmrc` (or use a supported newer SDK).
For Android, install Android Studio's SDK tools, an emulator system image, and
create an AVD. Set ANDROID_HOME or put `adb` and `emulator` on PATH.
For iOS, use macOS with Xcode and at least one downloaded iPhone simulator runtime.
The iOS example is SwiftPM-only; enable it with `flutter config --enable-swift-package-manager`.

From the repository root:

```sh
python3 tool/run_integration_tests.py --platform android
python3 tool/run_integration_tests.py --platform ios
```

The runner resolves dependencies, selects a running emulator/simulator or starts
an installed one, runs tests, writes reports, and stops only devices it started.
It does not install system images or runtimes automatically on a local computer.
CI handles provisioning its disposable Android emulator.

Optional arguments:

```sh
python3 tool/run_integration_tests.py --platform android --avd Pixel_API_35 --headless
python3 tool/run_integration_tests.py --platform android --device emulator-5554
python3 tool/run_integration_tests.py --platform ios --device <simulator-UDID>
python3 tool/run_integration_tests.py --platform android --flutter /path/to/flutter/bin/flutter
```

For direct execution on an already running target:

```sh
cd example
flutter pub get
flutter test integration_test/video_compress_test.dart -d <device-id> --reporter expanded
```

Reports from the runner are saved in `example/build/integration_results/<platform>/`.
One run per platform should use a checkout at a time because plugin state and
output cache are shared. Integration tests run in debug mode.

## Coverage

- Example launch and initial selection state.
- Metadata from filesystem paths and file URIs, including literal percent signs.
- Byte/file thumbnails at milliseconds and portrait rotation.
- Three-second trims with and without audio, including a real 15 fps assertion.
- Already-small/pass-through inputs still produce a usable output file.
- Progress bounds and finite values.
- Cancellation, rejection of overlapping requests, and successful restart.
- Native failures and recovery on the next request.
- Explicit deletion of a disposable source copy.
- Generated-cache cleanup while preserving original fixtures.

Audio-track presence and frame rate are checked independently with Android
MediaExtractor and iOS AVFoundation in a debug-only example-host channel. No
inspection method is added to the published package API. The iOS probe is enabled
by the example's Debug Swift compilation condition; release hosts do not register it.

## Fixtures

`assets/integration/synthetic.mp4` is six seconds of generated 320x180 test video
at 30 fps with a 440 Hz tone (H.264 baseline + AAC). `rotated.mp4` contains the
same media with a 90-degree display matrix. Each file is about 200 KB.
No fixture contains personal or third-party recordings.

They are committed, so neither developers nor CI need FFmpeg to run the tests.
To reproduce them with FFmpeg 6 or newer from `example/`:

```sh
ffmpeg -f lavfi -i 'testsrc2=size=320x180:rate=30:duration=6' \
  -f lavfi -i 'sine=frequency=440:sample_rate=44100:duration=6' \
  -c:v libx264 -profile:v baseline -preset veryfast -crf 32 -pix_fmt yuv420p \
  -g 30 -bf 0 -c:a aac -b:a 64k -movflags +faststart -shortest \
  assets/integration/synthetic.mp4
ffmpeg -display_rotation:v:0 90 -i assets/integration/synthetic.mp4 \
  -c copy assets/integration/rotated.mp4
```

Simulator/emulator results verify the implemented paths, not every physical
device's hardware encoder or the OS photo picker permission flows.
