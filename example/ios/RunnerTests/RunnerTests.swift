import Flutter
import UIKit
import XCTest
import AVFoundation
@testable import video_compress_zero

class RunnerTests: XCTestCase {
  // Generate real audio inside the test process. No bundled fixture or local
  // setup script is needed, and a silent video cannot accidentally pass.
  private func writeAudioFixture(to url: URL) throws {
    let sampleRate = 44_100.0
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * 6)))
    buffer.frameLength = buffer.frameCapacity
    let samples = try XCTUnwrap(buffer.floatChannelData)[0]
    for index in 0..<Int(buffer.frameLength) {
      samples[index] = Float(0.2 * sin(2 * Double.pi * 440 * Double(index) / sampleRate))
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
  }

  private func fixtureWithAudio() throws -> URL {
    let videoURL = try fixture()
    let audioURL = videoURL.deletingPathExtension().appendingPathExtension("caf")
    let outputURL = videoURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".mp4")
    defer {
      try? FileManager.default.removeItem(at: videoURL)
      try? FileManager.default.removeItem(at: audioURL)
    }
    try writeAudioFixture(to: audioURL)
    let videoAsset = AVURLAsset(url: videoURL)
    let audioAsset = AVURLAsset(url: audioURL)
    let video = try XCTUnwrap(videoAsset.tracks(withMediaType: .video).first)
    let audio = try XCTUnwrap(audioAsset.tracks(withMediaType: .audio).first)
    let composition = AVMutableComposition()
    let outputVideo = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
    let outputAudio = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
    let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 6, preferredTimescale: 600))
    try outputVideo.insertTimeRange(range, of: video, at: .zero)
    outputVideo.preferredTransform = video.preferredTransform
    try outputAudio.insertTimeRange(range.intersection(audio.timeRange), of: audio, at: .zero)
    let exporter = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality))
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    let done = expectation(description: "fixture with audio encoded")
    exporter.exportAsynchronously { done.fulfill() }
    wait(for: [done], timeout: 20)
    guard exporter.status == .completed else {
      try? FileManager.default.removeItem(at: outputURL)
      throw exporter.error ?? NSError(domain: "RunnerTests.fixtureWithAudio", code: 1)
    }
    return outputURL
  }

  private func fixture() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".mp4")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 48
    ])
    input.transform = CGAffineTransform(rotationAngle: .pi / 2)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
      sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                                   kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 48])
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    for second in 0..<6 {
      let deadline = Date().addingTimeInterval(5)
      while !input.isReadyForMoreMediaData && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
      XCTAssertTrue(input.isReadyForMoreMediaData)
      var pixel: CVPixelBuffer?
      XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32ARGB,
        [kCVPixelBufferCGImageCompatibilityKey as String: true,
         kCVPixelBufferCGBitmapContextCompatibilityKey as String: true] as CFDictionary, &pixel), kCVReturnSuccess)
      let buffer = try XCTUnwrap(pixel)
      CVPixelBufferLockBaseAddress(buffer, [])
      let context = try XCTUnwrap(CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 64, height: 48,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue))
      context.setFillColor((second < 3 ? UIColor.red : UIColor.blue).cgColor)
      context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
      CVPixelBufferUnlockBaseAddress(buffer, [])
      XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(second), timescale: 1)))
    }
    writer.endSession(atSourceTime: CMTime(value: 6, timescale: 1))
    input.markAsFinished()
    let done = expectation(description: "fixture encoded")
    writer.finishWriting { done.fulfill() }
    wait(for: [done], timeout: 10)
    XCTAssertEqual(writer.status, .completed)
    return url
  }

  func testThumbnailMillisecondsAndSingleOrientationTransform() throws {
    let source = try fixture()
    defer { try? FileManager.default.removeItem(at: source) }
    let plugin = SwiftVideoCompressZeroPlugin()
    var images: [UIImage] = []
    for position in [0, 5000] {
      let done = expectation(description: "thumbnail at milliseconds")
      plugin.handle(FlutterMethodCall(methodName: "getByteThumbnail", arguments: [
        "path": source.path, "quality": 100, "position": position
      ])) { value in
        if let data = value as? FlutterStandardTypedData, let image = UIImage(data: data.data) {
          images.append(image)
          XCTAssertEqual(image.size.width, 48)
          XCTAssertEqual(image.size.height, 64)
        } else { XCTFail("Expected JPEG thumbnail, received \(String(describing: value))") }
        done.fulfill()
      }
      wait(for: [done], timeout: 10)
    }
    XCTAssertEqual(images.count, 2)
    if images.count == 2 { XCTAssertNotEqual(images[0].pngData(), images[1].pngData()) }
  }

  func testTrimUsesSourceRangeOnceForBothAudioModes() throws {
    let source = try fixtureWithAudio()
    defer { try? FileManager.default.removeItem(at: source) }
    let sourceAsset = AVURLAsset(url: source)
    XCTAssertFalse(sourceAsset.tracks(withMediaType: .audio).isEmpty, "Fixture must contain audio")
    let plugin = SwiftVideoCompressZeroPlugin()
    for audio in [true, false] {
      let done = expectation(description: "trimmed export")
      plugin.handle(FlutterMethodCall(methodName: "compressVideo", arguments: [
        "path": source.path, "quality": 2, "deleteOrigin": false, "frameRate": 30,
        "startTime": 2, "duration": 3, "includeAudio": audio
      ])) { value in
        if let json = value as? String, let data = json.data(using: .utf8),
           let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let duration = info["duration"] as? Double, let path = info["path"] as? String {
          XCTAssertEqual(duration, 3000, accuracy: 150)
          XCTAssertTrue(FileManager.default.fileExists(atPath: path))
          let output = AVURLAsset(url: URL(fileURLWithPath: path))
          let audioTracks = output.tracks(withMediaType: .audio)
          XCTAssertEqual(audioTracks.isEmpty, !audio, "includeAudio must control the exported audio track")
          if audio, let track = audioTracks.first {
            XCTAssertEqual(track.timeRange.start.seconds, 0, accuracy: 0.15)
            XCTAssertEqual(track.timeRange.duration.seconds, 3, accuracy: 0.15)
          }
          try? FileManager.default.removeItem(atPath: path)
        } else { XCTFail("Expected trimmed output, received \(String(describing: value))") }
        done.fulfill()
      }
      wait(for: [done], timeout: 20)
    }
  }

  func testCancelSettlesCompressionAndLateSetupCannotFinishNewSession() {
    let plugin = SwiftVideoCompressZeroPlugin()
    let first = expectation(description: "first compression settled")
    let second = expectation(description: "second compression settled")
    var firstReplies = 0
    var secondReplies = 0
    let arguments: [String: Any] = ["path": "/missing.mp4", "quality": 2, "deleteOrigin": false, "frameRate": 30]
    plugin.handle(FlutterMethodCall(methodName: "compressVideo", arguments: arguments)) { value in
      firstReplies += 1
      XCTAssertNil(value)
      first.fulfill()
    }
    plugin.handle(FlutterMethodCall(methodName: "cancelCompression", arguments: nil)) { _ in }
    plugin.handle(FlutterMethodCall(methodName: "compressVideo", arguments: arguments)) { value in
      secondReplies += 1
      XCTAssertTrue(value is FlutterError)
      second.fulfill()
    }
    wait(for: [first, second], timeout: 10)
    XCTAssertEqual(firstReplies, 1)
    XCTAssertEqual(secondReplies, 1)
  }

  func testInvalidThumbnailAndCompressionArgumentsReturnErrors() {
    let plugin = SwiftVideoCompressZeroPlugin()
    for method in ["getByteThumbnail", "getFileThumbnail", "compressVideo"] {
      var count = 0
      plugin.handle(FlutterMethodCall(methodName: method, arguments: ["path": "/missing.mp4", "quality": 200])) { value in
        count += 1
        XCTAssertTrue(value is FlutterError)
      }
      XCTAssertEqual(count, 1)
    }
  }

  func testFileURLDecodingPreservesLiteralPercentSequences() {
    let path = "/tmp/a space %20.mp4"
    XCTAssertEqual(Utility.getPathUrl(path).path, path)
    XCTAssertEqual(Utility.getPathUrl(URL(fileURLWithPath: path).absoluteString).path, path)
  }
}
