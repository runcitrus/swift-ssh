// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SSH2",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SSH2", targets: ["SSH2"]),
    ],
    targets: [
        .target(
            name: "SSH2",
            dependencies: [
                "Clibcrypto",
                "Clibssh2",
            ]
        ),
        .binaryTarget(
            name: "Clibssh2",
            path: "Frameworks/Clibssh2.xcframework"
        ),
        .binaryTarget(
            name: "Clibcrypto",
            path: "Frameworks/Clibcrypto.xcframework"
        ),
    ]
)
