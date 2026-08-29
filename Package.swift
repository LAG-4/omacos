// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OMacOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "omacos-shell", targets: ["OMacOSShell"])
    ],
    targets: [
        .executableTarget(
            name: "OMacOSShell",
            resources: [.process("Resources")]
        )
    ]
)
