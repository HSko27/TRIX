// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "TRIXAI", platforms: [.macOS(.v14)], products: [.executable(name: "TRIXAI", targets: ["TRIXAI"])], targets: [.executableTarget(name: "TRIXAI", path: "Sources")])
