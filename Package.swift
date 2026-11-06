// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NetStatus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NetStatus", path: "Sources/NetStatus")
    ]
)
