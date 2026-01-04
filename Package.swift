// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "rustun-apple",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "rustun-client",
            targets: ["client"]
        )
    ],
    targets: [
        .executableTarget(
            name: "client",
            dependencies: [],
            path: "client",
            sources: [
                "main.swift",
                "Log.swift",
                "network/Crypto.swift",
                "network/Frame.swift",
                "network/FrameParser.swift",
                "network/RustunClient.swift",
                "network/TCPConnection.swift"
            ]
        )
    ]
)

