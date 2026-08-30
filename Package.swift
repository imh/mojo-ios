// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MojoIOS",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "MojoIOS", targets: ["MojoIOS"]),
    ],
    targets: [
        .binaryTarget(
            name: "MojoIOSCore",
            path: "build/MojoIOSCore.xcframework"
        ),
        .target(
            name: "MojoIOS",
            dependencies: ["MojoIOSCore"],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("Metal"),
            ]
        ),
        .testTarget(
            name: "MojoIOSTests",
            dependencies: ["MojoIOS", "MojoIOSCore"]
        ),
    ]
)
