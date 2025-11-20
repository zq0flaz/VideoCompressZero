import Flutter
import AVFoundation

public class SwiftVideoCompressZeroPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let channelName = "video_compress_zero"
    private var exporter: AVAssetExportSession? = nil
    private var stopCommand = false
    private var resultSent = false  // Track if result already sent to avoid double-call
    // Track the path currently being compressed so cancelCompression can return its info
    private var currentCompressingPath: String? = nil
    private var currentSessionId: String? = nil
    // Track if we've sent an initial 0% progress event (for waiting/preparing state)
    private var sentInitialProgress = false
    // Event channel support
    private var eventSink: FlutterEventSink? = nil
    private let eventChannelName = "video_compress_zero/events"
    private let channel: FlutterMethodChannel
    private let avController = AvController()
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "video_compress_zero", binaryMessenger: registrar.messenger())
        let instance = SwiftVideoCompressZeroPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Register event channel for progress/cancel/completed events
        let events = FlutterEventChannel(name: "video_compress_zero/events", binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "getByteThumbnail":
            guard let args = args,
                  let path = args["path"] as? String,
                  let quality = args["quality"] as? NSNumber,
                  let position = args["position"] as? NSNumber else {
                result(FlutterError(code: channelName, message: "Invalid arguments for getByteThumbnail", details: nil))
                return
            }
            getByteThumbnail(path, quality, position, result)
        case "getFileThumbnail":
            guard let args = args,
                  let path = args["path"] as? String,
                  let quality = args["quality"] as? NSNumber,
                  let position = args["position"] as? NSNumber else {
                result(FlutterError(code: channelName, message: "Invalid arguments for getFileThumbnail", details: nil))
                return
            }
            getFileThumbnail(path, quality, position, result)
        case "getMediaInfo":
            guard let args = args,
                  let path = args["path"] as? String else {
                result(FlutterError(code: channelName, message: "Invalid arguments for getMediaInfo", details: nil))
                return
            }
            getMediaInfo(path, result)
        case "compressVideo":
            guard let args = args,
                  let path = args["path"] as? String,
                  let quality = args["quality"] as? NSNumber,
                  let deleteOrigin = args["deleteOrigin"] as? Bool else {
                result(FlutterError(code: channelName, message: "Invalid arguments for compressVideo", details: nil))
                return
            }
            let startTime = args["startTime"] as? Double
            let duration = args["duration"] as? Double
            let includeAudio = args["includeAudio"] as? Bool
            let frameRate = args["frameRate"] as? Int
            compressVideo(path, quality, deleteOrigin, startTime, duration, includeAudio, frameRate, result)
        case "cancelCompression":
            cancelCompression(result)
        case "deleteAllCache":
            Utility.deleteFile(Utility.basePath(), clear: true)
            result(true)
        case "setLogLevel":
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    private func rotateUIImage(_ image: UIImage, degrees: Int) -> UIImage {
        let radians = CGFloat(degrees) * .pi / 180
        var newSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        // Handle iOS bug where width/height swap in portrait
        if degrees == 90 || degrees == 270 {
            newSize = CGSize(width: newSize.height, height: newSize.width)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return image }

        // Move origin to middle
        ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        ctx.rotate(by: radians)

        // Draw rotated image
        image.draw(in: CGRect(x: -image.size.width / 2,
                            y: -image.size.height / 2,
                            width: image.size.width,
                            height: image.size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return rotatedImage
    }
    
    private func getBitMap(_ path: String, _ quality: NSNumber, _ position: NSNumber, _ result: FlutterResult) -> Data? {
        let url = Utility.getPathUrl(path)
        let asset = avController.getVideoAsset(url)
        guard let track = avController.getTrack(asset) else {
            result(FlutterError(code: channelName, message: "Failed to get track", details: nil))
            return nil
        }

        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true

        let timeScale = asset.duration.timescale // track.nominalFrameRate
        let time = CMTimeMakeWithSeconds(Float64(truncating: position), preferredTimescale: CMTimeScale(timeScale))
        
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            var thumbnail = UIImage(cgImage: img)

            let orientationDegrees = avController.getVideoOrientation(path) ?? 0
            if orientationDegrees != 0 {
                thumbnail = rotateUIImage(thumbnail, degrees: orientationDegrees)
            }

            let compressionQuality = CGFloat(0.01 * Double(truncating: quality))
            return thumbnail.jpegData(compressionQuality: compressionQuality)
        } catch {
            result(FlutterError(code: channelName, message: "Failed to generate thumbnail", details: error.localizedDescription))
            return nil
        }
    }
    
    private func getByteThumbnail(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult) {
        if let bitmap = getBitMap(path,quality,position,result) {
            result(bitmap)
        }
    }
    
    private func getFileThumbnail(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult) {
        let fileName = Utility.getFileName(path)
        let url = Utility.getPathUrl("\(Utility.basePath())/\(fileName).jpg")
        Utility.deleteFile(url.path)
        if let bitmap = getBitMap(path,quality,position,result) {
            guard (try? bitmap.write(to: url)) != nil else {
                return result(FlutterError(code: channelName,message: "getFileThumbnail error",details: "getFileThumbnail error"))
            }
            result(Utility.excludeFileProtocol(url.absoluteString))
        }
    }
    
    public func getMediaInfoJson(_ path: String)->[String : Any?] {
        let url = Utility.getPathUrl(path)
        let asset = avController.getVideoAsset(url)
        guard let track = avController.getTrack(asset) else { return [:] }
        
        let playerItem = AVPlayerItem(url: url)
        let metadataAsset = playerItem.asset
        
        let orientation = avController.getVideoOrientation(path)
        
        let title = avController.getMetaDataByTag(metadataAsset,key: "title")
        let author = avController.getMetaDataByTag(metadataAsset,key: "author")
        
        let duration = asset.duration.seconds * 1000
        let filesize = track.totalSampleDataLength
        
        let size = track.naturalSize.applying(track.preferredTransform)
        
        let width = abs(size.width)
        let height = abs(size.height)
        
        let dictionary = [
            "path":Utility.excludeFileProtocol(path),
            "title":title,
            "author":author,
            "width":width,
            "height":height,
            "duration":duration,
            "filesize":filesize,
            "orientation":orientation
            ] as [String : Any?]
        return dictionary
    }
    
    private func getMediaInfo(_ path: String,_ result: FlutterResult) {
        let json = getMediaInfoJson(path)
        let string = Utility.keyValueToJson(json)
        result(string)
    }
    
    
    @objc private func updateProgress(timer:Timer) {
        guard let asset = timer.userInfo as? AVAssetExportSession else {
            NSLog("🔴 updateProgress: timer.userInfo is not AVAssetExportSession")
            timer.invalidate()
            return
        }

        // Status codes (AVAssetExportSession.Status):
        // 0: unknown, 1: waiting, 2: cancelled, 3: exporting, 4: completed, 5: failed
        let status = asset.status.rawValue
        let rawProgress = asset.progress
        NSLog("🟢 updateProgress: status=\(status), progress=\(rawProgress), stopCommand=\(stopCommand)")

        // Emit a single initial 0% while waiting/unknown to show preparing state
        if !sentInitialProgress && !stopCommand && (asset.status == .unknown || asset.status == .waiting) {
            sendEvent(["type": "progress", "progress": 0.0])
            sentInitialProgress = true
            return
        }

        // Active exporting progress
        if !stopCommand && asset.status == .exporting {
            sentInitialProgress = true // ensure flag set
            sendEvent(["type": "progress", "progress": rawProgress * 100])
            return
        }

        // Terminal states: completed / failed / cancelled OR externally stopped
        if stopCommand || asset.status == .completed || asset.status == .failed || asset.status == .cancelled {
            NSLog("🟡 updateProgress: invalidating timer, terminal status=\(status)")
            timer.invalidate()
            return
        }
        // For other states (waiting/unknown) we keep timer alive; progress will be emitted once exporting starts
    }
    
    private func getExportPreset(_ quality: NSNumber)->String {
        switch(quality) {
        case 1:
            return AVAssetExportPresetLowQuality    
        case 2:
            return AVAssetExportPresetMediumQuality
        case 3:
            return AVAssetExportPresetHighestQuality
        case 4:
            return AVAssetExportPreset640x480
        case 5:
            return AVAssetExportPreset960x540
        case 6:
            return AVAssetExportPreset1280x720
        case 7:
            return AVAssetExportPreset1920x1080
        default:
            return AVAssetExportPresetMediumQuality
        }
    }
    
    private func getComposition(_ isIncludeAudio: Bool,_ timeRange: CMTimeRange, _ sourceVideoTrack: AVAssetTrack)->AVAsset {
        let composition = AVMutableComposition()
        if !isIncludeAudio {
            let compressionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            compressionVideoTrack!.preferredTransform = sourceVideoTrack.preferredTransform
            try? compressionVideoTrack!.insertTimeRange(timeRange, of: sourceVideoTrack, at: CMTime.zero)
        } else {
            return sourceVideoTrack.asset!
        }
        
        return composition    
    }
    
    private func compressVideo(_ path: String,_ quality: NSNumber,_ deleteOrigin: Bool,_ startTime: Double?,
                               _ duration: Double?,_ includeAudio: Bool?,_ frameRate: Int?,
                               _ result: @escaping FlutterResult) {
        // Prevent concurrent compressions
        if self.exporter != nil {
            DispatchQueue.main.async {
                result(FlutterError(code: self.channelName, message: "Already compressing", details: nil))
            }
            return
        }

        // Reset state for new compression
        self.currentCompressingPath = path
        self.resultSent = false
        self.stopCommand = false  // Reset stopCommand for new compression
        let sourceVideoUrl = Utility.getPathUrl(path)
        let sourceVideoType = "mp4"
        
        let sourceVideoAsset = avController.getVideoAsset(sourceVideoUrl)
        guard let sourceVideoTrack = avController.getTrack(sourceVideoAsset) else {
            // Clean up state if track is nil
            self.currentCompressingPath = nil
            DispatchQueue.main.async {
                result(FlutterError(code: self.channelName, message: "Failed to get video track", details: nil))
            }
            return
        }

    let uuid = NSUUID()
    let sessionId = uuid.uuidString
    self.currentSessionId = sessionId
    let compressionUrl =
    Utility.getPathUrl("\(Utility.basePath())/\(Utility.getFileName(path))\(uuid.uuidString).\(sourceVideoType)")

    // do not return early; keep method-channel API compatibility and return final result in completion

        let timescale = sourceVideoAsset.duration.timescale
        let minStartTime = Double(startTime ?? 0)
        
        let videoDuration = sourceVideoAsset.duration.seconds
        let minDuration = Double(duration ?? videoDuration)
        let maxDurationTime = minStartTime + minDuration < videoDuration ? minDuration : videoDuration
        
        let cmStartTime = CMTimeMakeWithSeconds(minStartTime, preferredTimescale: timescale)
        let cmDurationTime = CMTimeMakeWithSeconds(maxDurationTime, preferredTimescale: timescale)
        let timeRange: CMTimeRange = CMTimeRangeMake(start: cmStartTime, duration: cmDurationTime)
        
        let isIncludeAudio = includeAudio != nil ? includeAudio! : true
        
        let session = getComposition(isIncludeAudio, timeRange, sourceVideoTrack)
        
        guard let exporter = AVAssetExportSession(asset: session, presetName: getExportPreset(quality)) else {
            // Clean up state before returning error
            self.currentCompressingPath = nil
            self.currentSessionId = nil
            DispatchQueue.main.async {
                result(FlutterError(code: self.channelName, message: "Failed to create exporter", details: nil))
            }
            return
        }

        // CRITICAL: Set exporter immediately BEFORE starting async work to prevent race condition
        self.exporter = exporter
        
        exporter.outputURL = compressionUrl
        exporter.outputFileType = AVFileType.mp4
        exporter.shouldOptimizeForNetworkUse = true
        
        if frameRate != nil {
            let videoComposition = AVMutableVideoComposition(propertiesOf: sourceVideoAsset)
            videoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate!))
            exporter.videoComposition = videoComposition
        }
        
        if !isIncludeAudio {
            exporter.timeRange = timeRange
        }
        
        Utility.deleteFile(compressionUrl.absoluteString)
        
        let timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateProgress),
                                         userInfo: exporter, repeats: true)
        
        exporter.exportAsynchronously {
            timer.invalidate()
            
            switch exporter.status {
            case .completed:
                if deleteOrigin {
                    Utility.deleteFile(path)
                }
                var json = self.getMediaInfoJson(Utility.excludeEncoding(compressionUrl.path))
                json["isCancel"] = false
                let jsonString = Utility.keyValueToJson(json)
                // emit completed event
                self.sendEvent(["type": "completed", "sessionId": sessionId, "data": json])
                // return final result for compressVideo call on main thread
                if !self.resultSent {
                    self.resultSent = true
                    DispatchQueue.main.async {
                        result(jsonString)
                    }
                }
            case .failed:
                // emit failed event
                self.sendEvent(["type": "failed", "sessionId": sessionId, "error": exporter.error?.localizedDescription ?? "unknown"])                
                if !self.resultSent {
                    self.resultSent = true
                    DispatchQueue.main.async {
                        result(FlutterError(code: self.channelName, message: "Compression failed", details: exporter.error?.localizedDescription))
                    }
                }
            case .cancelled:
                // If cancelled, return cancellation info for the original source
                let sourcePathForCancel = self.currentCompressingPath ?? path
                var json = self.getMediaInfoJson(sourcePathForCancel)
                json["isCancel"] = true
                let jsonString = Utility.keyValueToJson(json)
                // emit cancelled event (may be duplicate if cancelCompression already sent one)
                self.sendEvent(["type": "cancelled", "sessionId": sessionId, "data": json])
                // Only return result if not already sent by cancelCompression
                if !self.resultSent {
                    self.resultSent = true
                    DispatchQueue.main.async {
                        result(jsonString)
                    }
                }
            default:
                break
            }
            // Clear exporter and reset state
            self.exporter = nil
            self.stopCommand = false
            self.currentCompressingPath = nil
            self.currentSessionId = nil
            self.resultSent = false
        }
        // emit an event announcing the session start
        sendEvent(["type": "started", "sessionId": sessionId, "path": Utility.excludeFileProtocol(path)])
    }
    
    private func cancelCompression(_ result: FlutterResult) {
        stopCommand = true
        exporter?.cancelExport()

        // Emit cancellation info if we have a path
        if let path = currentCompressingPath {
            resultSent = true
            var json = getMediaInfoJson(path)
            json["isCancel"] = true
            var payload: [String: Any] = ["type": "cancelled", "data": json]
            if let sid = currentSessionId { payload["sessionId"] = sid }
            sendEvent(payload)
        }

        // Full state reset
        exporter = nil
        currentCompressingPath = nil
        currentSessionId = nil
        sentInitialProgress = false
        // Return nil for void method
        result(nil)
    }

    // Helper to send events on main thread
    private func sendEvent(_ payload: Any) {
        DispatchQueue.main.async {
            if let sink = self.eventSink {
                NSLog("🟢 iOS sending event: \(payload)")
                sink(payload)
            } else {
                NSLog("🔴 iOS event sink is nil, cannot send: \(payload)")
            }
        }
    }
    
}
