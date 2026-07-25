// swift-tools-version:6.2
import PackageDescription

let safetySettings: [SwiftSetting] = [
    .strictMemorySafety()
]

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
            dependencies: [],
            swiftSettings: safetySettings),
        .testTarget(
            name: "NeedleFoundationTests",
            dependencies: ["NeedleFoundation"],
            exclude: [],
            swiftSettings: safetySettings),
        .target(
            name: "NeedleFoundationTest",
            dependencies: ["NeedleFoundation"],
            swiftSettings: safetySettings),
        .testTarget(
            name: "NeedleFoundationTestTests",
            dependencies: ["NeedleFoundationTest"],
            exclude: [],
            swiftSettings: safetySettings),
    ],
    swiftLanguageModes: [.v6]
)
