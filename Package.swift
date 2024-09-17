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
                "CLibcrypto",
                "CLibz",
                "CLibssh2",
            ],
            cSettings: [
                .unsafeFlags([
                    "-I/opt/homebrew/opt/openssl/include",
                    "-I/opt/homebrew/opt/zlib/include",
                    "-I/opt/homebrew/opt/libssh2/include",
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-force_load",
                    "-Xlinker", "/opt/homebrew/opt/openssl/lib/libcrypto.a",
                    "-Xlinker", "/opt/homebrew/opt/zlib/lib/libz.a",
                    "-Xlinker", "/opt/homebrew/opt/libssh2/lib/libssh2.a",
                ]),
            ]
        ),
        .executableTarget(
            name: "DemoSSH",
            dependencies: ["SSH2", "CLibssh2"]
        ),
        .systemLibrary(
            name: "CLibcrypto",
            pkgConfig: nil,
            providers: []
        ),
        .systemLibrary(
            name: "CLibz",
            pkgConfig: nil,
            providers: []
        ),
        .systemLibrary(
            name: "CLibssh2",
            pkgConfig: nil,
            providers: []
        ),
    ]
)
