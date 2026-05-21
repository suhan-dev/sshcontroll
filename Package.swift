// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SSHcontroll",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SSHcontroll", targets: ["AControlApp"])
    ],
    targets: [
        .executableTarget(
            name: "AControlApp",
            path: "Sources/AControlApp"
        )
    ]
)
