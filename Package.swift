// swift-tools-version:6.0
// This fallback manifest lets Swift 6.0/6.1 toolchains (Xcode 16.x) resolve
// and build the package. Swift 6.2+ toolchains pick Package@swift-6.2.swift,
// which additionally enables strict memory safety (SE-0458).
import PackageDescription

let package = Package(
    name: "NeedleFoundation",
    products: [
        .library(name: "NeedleFoundation", targets: ["NeedleFoundation"]),
        .library(name: "NeedleFoundationTest", targets: ["NeedleFoundationTest"]),
        .plugin(name: "NeedleGeneratePlugin", targets: ["NeedleGeneratePlugin"]),
        .plugin(name: "NeedleBuildToolPlugin", targets: ["NeedleBuildToolPlugin"])
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "needle",
            path: "Generator/bin/needle.artifactbundle"),
        .plugin(
            name: "NeedleGeneratePlugin",
            capability: .command(
                intent: .custom(
                    verb: "needle",
                    description: "Run the Needle DI code generator"),
                permissions: [
                    .writeToPackageDirectory(reason: "Write the generated DI code file, e.g. Sources/App/NeedleGenerated.swift")
                ]),
            dependencies: ["needle"]),
        .plugin(
            name: "NeedleBuildToolPlugin",
            capability: .buildTool(),
            dependencies: ["needle"]),
        .target(
            name: "NeedleFoundation",
            dependencies: []),
        .testTarget(
            name: "NeedleFoundationTests",
            dependencies: ["NeedleFoundation"],
            exclude: []),
        .target(
            name: "NeedleFoundationTest",
            dependencies: ["NeedleFoundation"]),
        .testTarget(
            name: "NeedleFoundationTestTests",
            dependencies: ["NeedleFoundationTest"],
            exclude: []),
    ],
    swiftLanguageModes: [.v6]
)
