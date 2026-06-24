// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalPorts",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LocalPorts",
            path: "Sources/LocalPorts"
        )
    ]
)
