// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OneShot",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "OneShot", targets: ["OneShot"])
    ],
    targets: [
        .executableTarget(
            name: "OneShot",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
