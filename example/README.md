# Video Compress Zero example

A single screen demonstrates video selection, compression quality and frame rate,
optional audio, progress, cancellation, output preview and saving to the gallery.
The thumbnail example is available from the image button in the app bar.
The original video is preserved. Generated output remains in the plugin's
cache; save it to the gallery before clearing app data.

## Run and check

Use the Flutter version pinned in the repository's `.fvmrc`.
From this directory:

```sh
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter devices
fvm flutter run -d <device-id>
```

The iOS example uses Swift Package Manager and requires iOS 15 or later.
`ios/Podfile.cocoapods` preserves the former configuration for reference;
it is not used by the example. Do not run `pod install` for this app.
The plugin itself retains its CocoaPods support for other consuming apps.

Photo library access is requested by the gallery plugins when needed. No media
is uploaded. Android write permission is limited to Android API 29 and earlier.
macOS has Photos permission declarations, but this plugin currently declares
only Android and iOS support; the compression demo is supported on those two
platforms. Desktop branches are not a claim of macOS compression support.

## Device smoke test

Use a synthetic test video rather than personal media:

1. Select an MP4/MOV and check its size, duration and resolution.
2. Compress at 540p/30 fps, preview playback and audio, then save to Photos.
3. Verify the saved video in Photos. Repeat with Photos access denied; the
   output should remain available and the screen should show a retry message.
4. Start another compression and cancel. Selection, reset and restart must
   remain disabled until cancellation finishes.
5. Try a different quality, an output larger than the input, and a video with
   no audio. Missing metadata should display `Unavailable` rather than crash.
6. Open the thumbnail screen, cancel selection, then select a video. Navigate
   back while thumbnail loading is pending and check for lifecycle errors.

Automated tests use fake media paths and operations. They cover state and UI
behavior without accessing a real photo library. They do not replace device
checks of native encoding, playback, or Photos permissions.


## Automatic native integration tests

From the repository root, run:

```sh
python3 tool/run_integration_tests.py --platform android
python3 tool/run_integration_tests.py --platform ios
```

Use `--device <adb-serial-or-simulator-UDID>` to select a running target or
`--avd <name>` to select an installed Android AVD. The runner uses the local FVM
SDK when installed, otherwise Flutter on PATH. Use `--flutter <executable>` to
override it. See [coverage and prerequisites](integration_test/README.md).
