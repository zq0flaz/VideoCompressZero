import Flutter
import AVFoundation
import UIKit

public class SwiftVideoCompressZeroPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private final class Session {
        let id = UUID().uuidString
        let result: FlutterResult
        let path: String
        var exporter: AVAssetExportSession?
        var timer: Timer?
        var settled = false
        var cancellationRequested = false
        init(_ result: @escaping FlutterResult, path: String) { self.result = result; self.path = path }
    }
    private var active: Session?
    private var eventSink: FlutterEventSink?
    private let work = DispatchQueue(label: "video_compress_zero.media")
    private let avController = AvController()
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftVideoCompressZeroPlugin()
        let channel = FlutterMethodChannel(name: "video_compress_zero", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        FlutterEventChannel(name: "video_compress_zero/events", binaryMessenger: registrar.messenger()).setStreamHandler(instance)
    }
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? { eventSink = nil; return nil }
    private func failure(_ message: String, _ details: Any? = nil) -> FlutterError {
        return FlutterError(code: "video_compress_zero", message: message, details: details)
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "cancelCompression":
            if let session = active {
                session.cancellationRequested = true
                session.exporter?.cancelExport()
                // Setup/export completion settles the original request only after
                // the media worker stops touching its output.
            }
            result(nil)
        case "setLogLevel": result(nil) // No native media payload logging.
        case "deleteAllCache":
            guard active == nil else { result(failure("Cannot clear cache while compressing")); return }
            work.async {
                do {
                    try FileManager.default.removeItem(at: Utility.getPathUrl(Utility.basePath()))
                    DispatchQueue.main.async { result(true) }
                } catch { DispatchQueue.main.async { result(self.failure("Cache deletion failed", error.localizedDescription)) } }
            }
        case "getMediaInfo", "getByteThumbnail", "getFileThumbnail", "compressVideo":
            guard let path = args["path"] as? String, !path.isEmpty else { result(failure("Invalid path")); return }
            if call.method == "compressVideo" {
                guard active == nil else { result(failure("Already compressing")); return }
                guard let quality = args["quality"] as? Int, (0...7).contains(quality), let deleteOrigin = args["deleteOrigin"] as? Bool else { result(failure("Invalid compression arguments")); return }
                let frameRate = args["frameRate"] as? Int ?? 30
                let start = (args["startTime"] as? NSNumber)?.doubleValue ?? 0
                let duration = (args["duration"] as? NSNumber)?.doubleValue
                guard frameRate > 0, frameRate <= Int(Int32.max), start.isFinite, start >= 0, duration == nil || (duration!.isFinite && duration! > 0) else { result(failure("Invalid frame rate or trim range")); return }
                let session = Session(result, path: path)
                active = session
                eventSink?(["type": "started", "sessionId": session.id])
                compress(session, path: path, quality: quality, deleteOrigin: deleteOrigin, start: start, duration: duration, audio: args["includeAudio"] as? Bool ?? true, frameRate: frameRate)
            } else {
                let quality = args["quality"] as? Int ?? 100
                let position = (args["position"] as? NSNumber)?.doubleValue ?? -1
                guard (1...100).contains(quality), position.isFinite, position >= -1 else { result(failure("Invalid thumbnail arguments")); return }
                work.async {
                    do {
                        let value: Any
                        if call.method == "getMediaInfo" { value = Utility.keyValueToJson(try self.mediaInfo(path)) }
                        else {
                            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: Utility.getPathUrl(path)))
                            generator.appliesPreferredTrackTransform = true
                            generator.requestedTimeToleranceBefore = .zero
                            generator.requestedTimeToleranceAfter = .zero
                            generator.maximumSize = CGSize(width: 512, height: 512)
                            let image = try generator.copyCGImage(at: CMTime(seconds: max(0, position) / 1000, preferredTimescale: 600), actualTime: nil)
                            guard let data = UIImage(cgImage: image).jpegData(compressionQuality: CGFloat(quality) / 100) else { throw NSError(domain: "video_compress_zero", code: 1) }
                            if call.method == "getByteThumbnail" { value = FlutterStandardTypedData(bytes: data) }
                            else {
                                let url = Utility.getPathUrl(Utility.basePath()).appendingPathComponent(UUID().uuidString + ".jpg")
                                try data.write(to: url, options: .atomic)
                                value = url.path
                            }
                        }
                        DispatchQueue.main.async { result(value) }
                    } catch { DispatchQueue.main.async { result(self.failure("Media operation failed", error.localizedDescription)) } }
                }
            }
        default: result(FlutterMethodNotImplemented)
        }
    }
    private func mediaInfo(_ path: String) throws -> [String: Any?] {
        let url = Utility.getPathUrl(path)
        let asset = AVURLAsset(url: url)
        guard let track = avController.getTrack(asset) else { throw NSError(domain: "video_compress_zero", code: 2) }
        let size = track.naturalSize.applying(track.preferredTransform)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return ["path": url.path, "title": avController.getMetaDataByTag(asset, key: "title"), "author": avController.getMetaDataByTag(asset, key: "author"), "width": abs(size.width), "height": abs(size.height), "duration": asset.duration.seconds * 1000, "filesize": attributes[.size] ?? 0, "orientation": avController.getVideoOrientation(path) ?? 0]
    }
    private func compress(_ session: Session, path: String, quality: Int, deleteOrigin: Bool, start: Double, duration: Double?, audio: Bool, frameRate: Int) {
        work.async { [self] in
            do {
                let asset = AVURLAsset(url: Utility.getPathUrl(path))
                guard let video = self.avController.getTrack(asset) else { throw NSError(domain: "video_compress_zero", code: 2) }
                let length = asset.duration.seconds
                guard length.isFinite, start < length else { throw NSError(domain: "video_compress_zero", code: 3) }
                let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: min(duration ?? (length - start), length - start), preferredTimescale: 600))
                let composition = AVMutableComposition()
                guard let outputVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw NSError(domain: "video_compress_zero", code: 4) }
                try outputVideo.insertTimeRange(range, of: video, at: .zero)
                outputVideo.preferredTransform = video.preferredTransform
                if audio {
                    for track in asset.tracks(withMediaType: .audio) {
                        guard let outputAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw NSError(domain: "video_compress_zero", code: 4) }
                        let audioRange = range.intersection(track.timeRange)
                        if audioRange.duration > .zero {
                            try outputAudio.insertTimeRange(audioRange, of: track, at: CMTimeSubtract(audioRange.start, range.start))
                        }
                    }
                }
                let presets = [AVAssetExportPresetMediumQuality, AVAssetExportPresetLowQuality, AVAssetExportPresetMediumQuality, AVAssetExportPresetHighestQuality, AVAssetExportPreset640x480, AVAssetExportPreset960x540, AVAssetExportPreset1280x720, AVAssetExportPreset1920x1080]
                guard let exporter = AVAssetExportSession(asset: composition, presetName: presets[quality]) else { throw NSError(domain: "video_compress_zero", code: 5) }
                let url = Utility.getPathUrl(Utility.basePath()).appendingPathComponent(session.id + ".mp4")
                exporter.outputURL = url
                exporter.outputFileType = .mp4
                exporter.shouldOptimizeForNetworkUse = true
                let videoComposition = AVMutableVideoComposition(propertiesOf: composition)
                // The convenience initializer otherwise preserves the source
                // track's timing and ignores the requested output frame rate.
                videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
                videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(frameRate))
                exporter.videoComposition = videoComposition
                DispatchQueue.main.async {
                    guard self.active === session, !session.settled else { return }
                    if session.cancellationRequested {
                        self.finish(session, value: nil, type: "cancelled")
                        return
                    }
                    session.exporter = exporter
                    session.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                        guard let self = self, self.active === session else { return }
                        self.eventSink?(["type": "progress", "sessionId": session.id, "progress": exporter.progress * 100])
                    }
                    exporter.exportAsynchronously {
                        self.work.async {
                            var value: Any? = nil
                            var type = "failed"
                            if exporter.status == .completed {
                                do {
                                    var info = try self.mediaInfo(url.path)
                                    info["isCancel"] = false
                                    value = Utility.keyValueToJson(info)
                                    type = "completed"
                                } catch { value = self.failure("Output metadata failed", error.localizedDescription) }
                            } else if exporter.status == .cancelled { type = "cancelled" }
                            else { value = self.failure("Compression failed", exporter.error?.localizedDescription) }
                            let finalValue = value
                            let finalType = type
                            DispatchQueue.main.async {
                                guard !session.settled else { Utility.deleteFile(url.path); return }
                                if session.cancellationRequested {
                                    Utility.deleteFile(url.path)
                                    self.finish(session, value: nil, type: "cancelled")
                                } else {
                                    if finalType == "completed", deleteOrigin { Utility.deleteFile(path) }
                                    if finalType != "completed" { Utility.deleteFile(url.path) }
                                    self.finish(session, value: finalValue, type: finalType)
                                }
                            }
                        }
                    }
                }
            } catch { DispatchQueue.main.async { self.finish(session, value: session.cancellationRequested ? nil : self.failure("Compression setup failed", error.localizedDescription), type: session.cancellationRequested ? "cancelled" : "failed") } }
        }
    }
    private func finish(_ session: Session, value: Any?, type: String) {
        guard !session.settled else { return }
        session.settled = true
        session.timer?.invalidate()
        session.timer = nil
        if active === session {
            active = nil
            var event: [String: Any] = ["type": type, "sessionId": session.id]
            if let json = value as? String, let data = json.data(using: .utf8),
               let info = try? JSONSerialization.jsonObject(with: data) {
                event["data"] = info
            } else if type == "cancelled" {
                event["data"] = ["path": Utility.getPathUrl(session.path).path, "isCancel": true]
            } else if let error = value as? FlutterError {
                event["error"] = error.details as? String ?? error.message ?? "Compression failed"
            }
            eventSink?(event)
        }
        session.result(value)
    }
}
