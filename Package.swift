// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AutoFoto Legal Expres",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AutoFoto Legal Expres", targets: ["AutoFotoLegalExpres"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AutoFotoLegalExpres",
            dependencies: [],
            path: "Sources"
        )
    ]
)
