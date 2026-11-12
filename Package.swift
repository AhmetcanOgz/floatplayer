// swift-tools-version:5.9
import PackageDescription

// swift-testing links lib_TestingInterop, which Command Line Tools keep outside the default search path.
let testingInteropDir = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

let package = Package(
    name: "FloatPlayer",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Command Line Tools ship no XCTest, and SwiftPM's generated test runner can't see the CLT Testing.framework.
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.2.0"),
    ],
    targets: [
        .target(name: "FloatPlayerCore"),
        .executableTarget(name: "FloatPlayer", dependencies: ["FloatPlayerCore"]),
        .testTarget(
            name: "FloatPlayerCoreTests",
            dependencies: ["FloatPlayerCore", .product(name: "Testing", package: "swift-testing")],
            linkerSettings: [.unsafeFlags([
                "-L", testingInteropDir, "-Xlinker", "-rpath", "-Xlinker", testingInteropDir,
            ])]
        ),
    ]
)
