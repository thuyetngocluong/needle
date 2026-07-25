//
//  Copyright (c) 2026. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import PackagePlugin

/// A build tool plugin that runs the bundled `needle` code generator before
/// compiling the target it is applied to, so the generated DI registration
/// code is always up to date without a separate generator installation.
///
/// The generator parses exactly the Swift files declared by the target it is
/// attached to plus those of its dependency targets in the same package (or,
/// for Xcode projects, its dependency targets in the same project). The same
/// file set is declared as the build command's inputs, so regeneration
/// triggers whenever — and only when — any parsed file changes. Components
/// declared in other packages are not parsed; use the `needle` command plugin
/// for full control over the parsed paths in that case.
@main
struct NeedleBuildToolPlugin: BuildToolPlugin {

    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceModule = target as? SourceModuleTarget else {
            return []
        }

        let ownTargetIds = Set(context.package.targets.map { $0.id })
        var scanModules: [SourceModuleTarget] = [sourceModule]
        for dependency in sourceModule.recursiveTargetDependencies {
            guard let dependencyModule = dependency as? SourceModuleTarget else {
                continue
            }
            // Only parse modules of the consumer's own package; sources of
            // external packages are not part of this app's DI declaration.
            if ownTargetIds.contains(dependencyModule.id) {
                scanModules.append(dependencyModule)
            }
        }

        let inputFiles = scanModules.flatMap { module in
            module.sourceFiles(withSuffix: "swift").map { $0.url }
        }
        return [
            try makeNeedleCommand(
                displayName: "Needle Generate (\(target.name))",
                executable: try context.tool(named: "needle").url,
                inputFiles: inputFiles,
                workDirectory: context.pluginWorkDirectoryURL)
        ]
    }

    /// Builds the `needle generate` command for the given Swift files. The
    /// exact file set is passed to the generator through a newline-separated
    /// sources-list file and is also declared as the command's inputs, keeping
    /// the parsed set and the incremental-build tracking in lockstep.
    private func makeNeedleCommand(
        displayName: String,
        executable: URL,
        inputFiles: [URL],
        workDirectory: URL) throws -> Command {
        let output = workDirectory.appending(path: "NeedleGenerated.swift")
        let sourcesList = workDirectory.appending(path: "needle-sources.txt")
        try writeIfChanged(inputFiles.map { $0.path }.joined(separator: "\n"), to: sourcesList)

        return .buildCommand(
            displayName: displayName,
            executable: executable,
            arguments: ["generate", output.path, sourcesList.path],
            inputFiles: inputFiles + [sourcesList],
            outputFiles: [output])
    }

    /// Writes only when the content differs, so the file's modification time
    /// does not change on every plugin evaluation and invalidate the build
    /// command's inputs spuriously.
    private func writeIfChanged(_ content: String, to url: URL) throws {
        if let existing = try? String(contentsOf: url, encoding: .utf8), existing == content {
            return
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension NeedleBuildToolPlugin: XcodeBuildToolPlugin {

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        var visitedTargetIds = Set<XcodeTarget.ID>()
        var inputFiles = [URL]()
        collectSwiftInputFiles(of: target, visitedTargetIds: &visitedTargetIds, into: &inputFiles)

        return [
            try makeNeedleCommand(
                displayName: "Needle Generate (\(target.displayName))",
                executable: try context.tool(named: "needle").url,
                inputFiles: inputFiles,
                workDirectory: context.pluginWorkDirectoryURL)
        ]
    }

    /// Collects the Swift input files of the given target and, recursively,
    /// of its dependency targets within the same Xcode project. Product
    /// dependencies (external packages) are not part of this app's DI
    /// declaration and are not parsed.
    private func collectSwiftInputFiles(
        of target: XcodeTarget,
        visitedTargetIds: inout Set<XcodeTarget.ID>,
        into inputFiles: inout [URL]) {
        guard !visitedTargetIds.contains(target.id) else {
            return
        }
        visitedTargetIds.insert(target.id)

        inputFiles.append(contentsOf: target.inputFiles
            .filter { $0.url.pathExtension == "swift" }
            .map { $0.url })

        for dependency in target.dependencies {
            if case .target(let dependencyTarget) = dependency {
                collectSwiftInputFiles(of: dependencyTarget, visitedTargetIds: &visitedTargetIds, into: &inputFiles)
            }
        }
    }
}
#endif
