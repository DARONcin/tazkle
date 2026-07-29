// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Tazkle",
    defaultLocalization: "es",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Tazkle", targets: ["TazkleApp"]),
        .library(name: "TazkleAuthentication", targets: ["TazkleAuthentication"]),
        .library(name: "TazkleDomain", targets: ["TazkleDomain"]),
        .library(name: "TazkleDesignSystem", targets: ["TazkleDesignSystem"]),
        .library(name: "TazklePersistence", targets: ["TazklePersistence"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            path: "apps/macos/Sources/CSQLite"
        ),
        .target(
            name: "TazkleDomain",
            path: "packages/contracts/Sources/TazkleDomain"
        ),
        .target(
            name: "TazkleDesignSystem",
            path: "packages/design-system/Sources/TazkleDesignSystem"
        ),
        .target(
            name: "TazklePersistence",
            dependencies: ["CSQLite", "TazkleDomain"],
            path: "apps/macos/Sources/TazklePersistence"
        ),
        .target(
            name: "TazkleAuthentication",
            path: "apps/macos/Sources/TazkleAuthentication"
        ),
        .executableTarget(
            name: "TazkleApp",
            dependencies: [
                "TazkleAuthentication",
                "TazkleDomain",
                "TazkleDesignSystem",
                "TazklePersistence",
            ],
            path: "apps/macos/Sources/TazkleApp",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TazkleAuthenticationTests",
            dependencies: ["TazkleAuthentication"],
            path: "apps/macos/Tests/TazkleAuthenticationTests"
        ),
        .testTarget(
            name: "TazkleDomainTests",
            dependencies: ["TazkleDomain"],
            path: "apps/macos/Tests/TazkleDomainTests"
        ),
        .testTarget(
            name: "TazklePersistenceTests",
            dependencies: ["CSQLite", "TazkleDomain", "TazklePersistence"],
            path: "apps/macos/Tests/TazklePersistenceTests"
        )
    ]
)
