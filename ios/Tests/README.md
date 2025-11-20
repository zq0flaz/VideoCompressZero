# iOS Unit Tests for VideoCompressZero

This directory contains unit tests for the iOS native implementation of the VideoCompressZero plugin.

## Test Files

- **AvControllerTests.swift** - Tests for video asset operations and orientation detection
- **UtilityTests.swift** - Tests for file operations and JSON serialization  
- **SwiftVideoCompressZeroPluginTests.swift** - Tests for the main plugin class

## How to Run These Tests

Since this is a Flutter plugin, iOS tests need to be integrated into a test target. Here are your options:

### Option 1: Add to Example App (Recommended for Development)

1. Open `example/ios/Runner.xcworkspace` in Xcode
2. Create a new test target:
   - File → New → Target
   - Select "iOS Unit Testing Bundle"
   - Name it `VideoCompressZeroTests`
3. Add test files:
   - Right-click on the test target in Project Navigator
   - Add Files to "VideoCompressZeroTests"
   - Navigate to `ios/Tests/` and select all `.swift` files
   - Make sure "Copy items if needed" is unchecked (reference only)
   - Add to `VideoCompressZeroTests` target
4. Configure test target:
   - Select the test target in Project Settings
   - Under "General" → "Host Application", select "Runner"
   - Under "Build Settings" → "Search Paths", add path to plugin classes
5. Run tests:
   - Press ⌘U (or Product → Test)

### Option 2: Command Line via Example App

```bash
cd example/ios
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Option 3: Create Standalone Test Project

For CI/CD integration, you can create a separate test project:

```bash
# Create a new iOS app project to host tests
# Add the plugin as a pod dependency
# Import test files
# Configure CI/CD to run xcodebuild test
```

## Test Coverage

The tests cover:

- ✅ Video orientation detection (transform matrix calculations)
- ✅ Track loading from video assets
- ✅ Metadata extraction
- ✅ File path handling and URL conversion
- ✅ JSON serialization of video info
- ✅ Export preset quality mapping
- ✅ Progress tracking logic
- ✅ Status management

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Run iOS Tests
  run: |
    cd example/ios
    xcodebuild test \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      -sdk iphonesimulator \
      -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Fastlane Example

```ruby
lane :test do
  run_tests(
    workspace: "example/ios/Runner.xcworkspace",
    scheme: "Runner",
    devices: ["iPhone 15"]
  )
end
```

## Writing New Tests

When adding new iOS functionality:

1. Create corresponding test methods in the appropriate test file
2. Use `XCTAssert*` methods for assertions
3. Follow naming convention: `test<MethodName>_<Scenario>_<ExpectedResult>`
4. Add test data files to the test bundle if needed

Example:

```swift
func testCompression_withValidVideo_completesSuccessfully() {
    // Arrange
    let videoURL = URL(fileURLWithPath: "/path/to/test/video.mp4")
    
    // Act
    let result = compress(video: videoURL, quality: .medium)
    
    // Assert
    XCTAssertNotNil(result)
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
}
```

## Troubleshooting

**Tests not compiling?**
- Make sure test target has access to plugin classes
- Check "Build Settings" → "Swift Compiler - Search Paths"
- Add header search paths if needed

**Tests not running?**
- Verify Host Application is set to "Runner"
- Check that test files are added to test target membership
- Ensure simulator is available

**Import errors?**
- Tests use `@testable import` to access internal classes
- Make sure module name matches in Build Settings

## Notes

- These tests use XCTest framework (built into Xcode)
- Tests run on iOS Simulator
- Performance tests measure actual execution time
- Tests are independent and can run in any order
