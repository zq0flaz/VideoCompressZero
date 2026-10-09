import Flutter
import UIKit
import XCTest
import AVFoundation
@testable import video_compress_zero

class RunnerTests: XCTestCase {
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
    let source = try fixture()
    defer { try? FileManager.default.removeItem(at: source) }
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
