// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SSH2",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SSH2", targets: ["SSH2"]),
        .executable(name: "DemoSSH", targets: ["DemoSSH"]),
    ],
    targets: [
        .target(
            name: "SSH2",
            dependencies: [
                "CLibssh2",
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "./Contrib/lib/libcrypto.a",
                    "-Xlinker", "./Contrib/lib/libssh2.a",
                ]),
            ]
        ),
        .systemLibrary(
            name: "CLibssh2",
            pkgConfig: nil,
            providers: []
        ),
        .executableTarget(
            name: "DemoSSH",
            dependencies: ["SSH2"]
        ),
    ]
)
