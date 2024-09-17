// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DemoSSH",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DemoSSH", targets: ["DemoSSH"]),
    ],
    targets: [
        .executableTarget(
            name: "DemoSSH",
            dependencies: ["CLibcrypto", "CLibz", "CLibssh2"],
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
