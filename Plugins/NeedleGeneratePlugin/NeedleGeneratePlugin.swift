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

/// A command plugin that forwards its arguments verbatim to the bundled
/// `needle` code generator, so consumers can run the generator without a
/// separate installation:
///
///     swift package --allow-writing-to-package-directory needle \
///         generate Sources/App/NeedleGenerated.swift Sources/App
@main
struct NeedleGeneratePlugin: CommandPlugin {

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try run(tool: context.tool(named: "needle"), arguments: arguments)
    }

    private func run(tool: PluginContext.Tool, arguments: [String]) throws {
        let process = Process()
        process.executableURL = tool.url
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            Diagnostics.error("needle exited with status \(process.terminationStatus)")
            throw NeedleGenerateError.generatorFailed(status: process.terminationStatus)
        }
    }
}

enum NeedleGenerateError: Error {
    case generatorFailed(status: Int32)
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension NeedleGeneratePlugin: XcodeCommandPlugin {

    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let tool = try context.tool(named: "needle")
        let process = Process()
        process.executableURL = tool.url
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            Diagnostics.error("needle exited with status \(process.terminationStatus)")
            throw NeedleGenerateError.generatorFailed(status: process.terminationStatus)
        }
    }
}
#endif
