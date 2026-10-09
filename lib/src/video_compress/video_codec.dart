/// Video codec to use for compression.
enum VideoCodec {
  /// H.264/AVC — widely compatible, default on all platforms.
  h264,

  /// H.265/HEVC — roughly 40% smaller at equivalent quality.
  ///
  /// - iOS 11+ / macOS 10.13+: uses native AVFoundation HEVC presets.
  /// - Android API 21+: requires a hardware HEVC encoder; falls back to H.264
  ///   automatically when no hardware encoder is found on the device.
  hevc,
}
