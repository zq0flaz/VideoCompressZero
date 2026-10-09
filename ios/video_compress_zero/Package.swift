// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "video_compress_zero",
    platforms: [.iOS("13.0")],
    products: [.library(name: "video-compress-zero", targets: ["video_compress_zero"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(name: "video_compress_zero", dependencies: [
            .product(name: "FlutterFramework", package: "FlutterFramework")
        ])
    ]
)
