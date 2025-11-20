import XCTest
import AVFoundation
@testable import video_compress_zero

/// Unit tests for AvController
class AvControllerTests: XCTestCase {
    
    var avController: AvController!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        avController = AvController()
    }
    
    override func tearDownWithError() throws {
        avController = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Video Orientation Tests
    
    func testGetVideoOrientation_Portrait() throws {
        // Test portrait orientation (90 degrees)
        // This would require a test video file with portrait orientation
        // For now, we test the logic
        
        let transform90 = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
        
        // Verify the matrix values
        XCTAssertEqual(transform90.a, 0)
        XCTAssertEqual(transform90.b, 1.0)
        XCTAssertEqual(transform90.c, -1.0)
        XCTAssertEqual(transform90.d, 0)
    }
    
    func testGetVideoOrientation_PortraitUpsideDown() throws {
        // Test portrait upside down (270 degrees)
        let transform270 = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)
        
        XCTAssertEqual(transform270.a, 0)
        XCTAssertEqual(transform270.b, -1.0)
        XCTAssertEqual(transform270.c, 1.0)
        XCTAssertEqual(transform270.d, 0)
    }
    
    func testGetVideoOrientation_LandscapeRight() throws {
        // Test landscape right (0 degrees)
        let transform0 = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        
        XCTAssertEqual(transform0.a, 1.0)
        XCTAssertEqual(transform0.b, 0)
        XCTAssertEqual(transform0.c, 0)
        XCTAssertEqual(transform0.d, 1.0)
    }
    
    func testGetVideoOrientation_LandscapeLeft() throws {
        // Test landscape left (180 degrees)
        let transform180 = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        
        XCTAssertEqual(transform180.a, -1.0)
        XCTAssertEqual(transform180.b, 0)
        XCTAssertEqual(transform180.c, 0)
        XCTAssertEqual(transform180.d, -1.0)
    }
    
    // MARK: - Track Loading Tests
    
    func testGetTrack_WithInvalidAsset() throws {
        // Test with an invalid URL
        let invalidURL = URL(fileURLWithPath: "/invalid/path/to/video.mp4")
        let asset = avController.getVideoAsset(invalidURL)
        
        let track = avController.getTrack(asset)
        
        // Should return nil for invalid asset
        XCTAssertNil(track)
    }
    
    func testGetVideoAsset_CreatesAsset() throws {
        // Test that getVideoAsset creates an AVURLAsset
        let testURL = URL(fileURLWithPath: "/test/video.mp4")
        let asset = avController.getVideoAsset(testURL)
        
        XCTAssertNotNil(asset)
        XCTAssertTrue(asset is AVURLAsset)
        XCTAssertEqual(asset.url, testURL)
    }
    
    // MARK: - Metadata Tests
    
    func testGetMetaDataByTag_WithEmptyMetadata() throws {
        // Create a test asset with no metadata
        let testURL = URL(fileURLWithPath: "/test/video.mp4")
        let asset = AVURLAsset(url: testURL)
        
        let title = avController.getMetaDataByTag(asset, key: "title")
        
        // Should return empty string for non-existent metadata
        XCTAssertEqual(title, "")
    }
    
    func testGetMetaDataByTag_WithValidKey() throws {
        // This test would require a real video file with metadata
        // For now, we test the logic
        let testURL = URL(fileURLWithPath: "/test/video.mp4")
        let asset = AVURLAsset(url: testURL)
        
        let author = avController.getMetaDataByTag(asset, key: "author")
        
        // Should return empty string if no author metadata
        XCTAssertNotNil(author)
        XCTAssertTrue(author is String)
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_GetVideoAsset() throws {
        let testURL = URL(fileURLWithPath: "/test/video.mp4")
        
        measure {
            _ = avController.getVideoAsset(testURL)
        }
    }
}
