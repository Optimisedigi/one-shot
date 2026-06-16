// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Shotter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Shotter", targets: ["Shotter"])
    ],
    targets: [
        .executableTarget(
            name: "Shotter",
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
