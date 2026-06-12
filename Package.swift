// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vaulta",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Vaulta", targets: ["Vaulta"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "VaultaCore"),
        .executableTarget(
            name: "Vaulta",
            dependencies: ["VaultaCore"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "VaultaCoreTests",
            dependencies: ["VaultaCore"]
        ),
    ]
)
