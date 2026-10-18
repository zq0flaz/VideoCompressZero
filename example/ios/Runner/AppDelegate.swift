import UIKit
import Flutter
#if DEBUG
import AVFoundation
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
#if DEBUG
  private var mediaProbe: FlutterMethodChannel?
  private let probeQueue = DispatchQueue(label: "example.integration.media-probe")
#endif
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
#if DEBUG
    // Example-host test probe only; no additional API in the compression plugin.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IntegrationMediaProbe") else { return }
    let channel = FlutterMethodChannel(name: "video_compress_zero_example/media_probe", binaryMessenger: registrar.messenger())
    mediaProbe = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "inspect" else { result(FlutterMethodNotImplemented); return }
      guard let arguments = call.arguments as? [String: Any], let path = arguments["path"] as? String else {
        result(FlutterError(code: "media_probe", message: "Missing media path", details: nil)); return
      }
      self?.probeQueue.async {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let video = asset.tracks(withMediaType: .video).first else {
          DispatchQueue.main.async { result(FlutterError(code: "media_probe", message: "No video track", details: nil)) }
          return
        }
        let data: [String: Any] = [
          "audioTracks": asset.tracks(withMediaType: .audio).count,
          "frameRate": Double(video.nominalFrameRate)
        ]
        DispatchQueue.main.async { result(data) }
      }
    }
#endif
  }
}
