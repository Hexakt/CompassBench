// swift-tools-version: 5.9
import PackageDescription

// Seul le coeur mathématique (CompassBench/Core) est compilé par SwiftPM, pour
// permettre `swift test` en CI, y compris sur Linux. L'app iOS (CompassBench/App)
// se construit via Xcode.
let package = Package(
    name: "CompassBenchCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "CompassBenchCore", targets: ["CompassBenchCore"])],
    targets: [
        .target(name: "CompassBenchCore", path: "CompassBench/Core"),
        .testTarget(name: "CompassBenchCoreTests", dependencies: ["CompassBenchCore"], path: "Tests")
    ]
)
