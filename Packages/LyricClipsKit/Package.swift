// swift-tools-version: 6.0
import PackageDescription

let coreModules = ["LCCore", "LCText", "LCAlign", "LCTiming", "LCTemplates", "LCSubtitles", "LCModelStore"]
var targets: [Target] = coreModules.map { name in
    .target(name: name, dependencies: name == "LCCore" ? [.product(name: "Crypto", package: "swift-crypto")] : [.target(name: "LCCore")])
}
var products = coreModules.map { Product.library(name: $0, targets: [$0]) }
var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.3.0")
]

// Apple dependencies, including future binaryTarget declarations, belong inside this block.
#if !os(Linux)
let appleModules = ["LCAppleText", "LCAudio", "LCSeparation", "LCTranscription", "LCRender", "LCExport", "LCPipeline", "LCUI"]
targets += appleModules.map { .target(name: $0, dependencies: [.target(name: "LCCore")]) }
products += appleModules.map { Product.library(name: $0, targets: [$0]) }
#endif

targets.append(.testTarget(name: "LCCoreTests", dependencies: [.target(name: "LCCore")], resources: [.copy("Fixtures")]))
let package = Package(
    name: "LyricClipsKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: products,
    dependencies: dependencies,
    targets: targets,
    swiftLanguageModes: [.v6]
)
