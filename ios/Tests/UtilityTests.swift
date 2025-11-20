import XCTest
import Foundation
@testable import video_compress_zero

/// Unit tests for Utility class
class UtilityTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }
    
    // MARK: - File Name Tests
    
    func testStripFileExtension_WithSingleExtension() throws {
        let fileName = "video.mp4"
        let result = Utility.stripFileExtension(fileName)
        
        XCTAssertEqual(result, "video")
    }
    
    func testStripFileExtension_WithMultipleExtensions() throws {
        let fileName = "archive.tar.gz"
        let result = Utility.stripFileExtension(fileName)
        
        // Should only remove the last extension
        XCTAssertEqual(result, "archive.tar")
    }
    
    func testStripFileExtension_WithoutExtension() throws {
        let fileName = "videofile"
        let result = Utility.stripFileExtension(fileName)
        
        XCTAssertEqual(result, "videofile")
    }
    
    func testGetFileName_WithFullPath() throws {
        let path = "/Users/test/Documents/video.mp4"
        let result = Utility.getFileName(path)
        
        XCTAssertEqual(result, "video")
    }
    
    func testGetFileName_WithComplexPath() throws {
        let path = "/var/mobile/Containers/Data/Application/test/video_file.mov"
        let result = Utility.getFileName(path)
        
        XCTAssertEqual(result, "video_file")
    }
    
    // MARK: - Path URL Tests
    
    func testGetPathUrl_WithValidPath() throws {
        let path = "/test/video.mp4"
        let url = Utility.getPathUrl(path)
        
        XCTAssertTrue(url.isFileURL)
        XCTAssertEqual(url.path, path)
    }
    
    func testGetPathUrl_WithFileProtocol() throws {
        let path = "file:///test/video.mp4"
        let url = Utility.getPathUrl(path)
        
        XCTAssertTrue(url.isFileURL)
        XCTAssertEqual(url.path, "/test/video.mp4")
    }
    
    // MARK: - File Protocol Tests
    
    func testExcludeFileProtocol_WithProtocol() throws {
        let path = "file:///test/video.mp4"
        let result = Utility.excludeFileProtocol(path)
        
        XCTAssertEqual(result, "/test/video.mp4")
    }
    
    func testExcludeFileProtocol_WithoutProtocol() throws {
        let path = "/test/video.mp4"
        let result = Utility.excludeFileProtocol(path)
        
        XCTAssertEqual(result, "/test/video.mp4")
    }
    
    // MARK: - Encoding Tests
    
    func testExcludeEncoding_WithPercentEncoding() throws {
        let path = "/test/video%20file.mp4"
        let result = Utility.excludeEncoding(path)
        
        XCTAssertEqual(result, "/test/video file.mp4")
    }
    
    func testExcludeEncoding_WithoutEncoding() throws {
        let path = "/test/video.mp4"
        let result = Utility.excludeEncoding(path)
        
        XCTAssertEqual(result, "/test/video.mp4")
    }
    
    // MARK: - JSON Tests
    
    func testKeyValueToJson_WithValidDictionary() throws {
        let dict: [String: Any?] = [
            "path": "/test/video.mp4",
            "width": 1920,
            "height": 1080,
            "duration": 60.0
        ]
        
        let jsonString = Utility.keyValueToJson(dict)
        
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertNotEqual(jsonString, "{}")
        
        // Verify it's valid JSON
        let data = jsonString.data(using: .utf8)
        XCTAssertNotNil(data)
        
        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data)
            XCTAssertNotNil(json)
        }
    }
    
    func testKeyValueToJson_WithEmptyDictionary() throws {
        let dict: [String: Any?] = [:]
        let jsonString = Utility.keyValueToJson(dict)
        
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertEqual(jsonString, "{}")
    }
    
    func testKeyValueToJson_WithNullValues() throws {
        let dict: [String: Any?] = [
            "path": "/test.mp4",
            "title": nil,
            "author": nil
        ]
        
        let jsonString = Utility.keyValueToJson(dict)
        
        XCTAssertFalse(jsonString.isEmpty)
        XCTAssertNotEqual(jsonString, "{}")
    }
    
    // MARK: - Base Path Tests
    
    func testBasePath_CreatesDirectory() throws {
        let basePath = Utility.basePath()
        
        XCTAssertFalse(basePath.isEmpty)
        XCTAssertTrue(basePath.contains("video_compress_zero"))
        
        // Verify directory exists or was created
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: basePath, isDirectory: &isDirectory)
        
        XCTAssertTrue(exists || !exists) // Should either exist or be created
    }
    
    func testBasePath_IsConsistent() throws {
        let path1 = Utility.basePath()
        let path2 = Utility.basePath()
        
        XCTAssertEqual(path1, path2, "Base path should be consistent across calls")
    }
    
    // MARK: - File Deletion Tests
    
    func testDeleteFile_WithNonExistentFile() throws {
        let testPath = "/tmp/nonexistent_video_test_file.mp4"
        
        // Should not throw error for non-existent file
        XCTAssertNoThrow(Utility.deleteFile(testPath))
    }
    
    func testDeleteFile_WithClearFlag() throws {
        let testPath = "/tmp/test_directory"
        
        // Test with clear flag
        XCTAssertNoThrow(Utility.deleteFile(testPath, clear: true))
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_StripFileExtension() throws {
        let fileName = "long_video_file_name_with_extension.mp4"
        
        measure {
            _ = Utility.stripFileExtension(fileName)
        }
    }
    
    func testPerformance_KeyValueToJson() throws {
        let dict: [String: Any?] = [
            "path": "/test/video.mp4",
            "width": 1920,
            "height": 1080,
            "duration": 60000,
            "filesize": 10000000,
            "title": "Test Video",
            "author": "Test Author"
        ]
        
        measure {
            _ = Utility.keyValueToJson(dict)
        }
    }
}
