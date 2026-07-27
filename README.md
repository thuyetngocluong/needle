# ![](Images/logo.png)

[![Build Status](https://travis-ci.com/uber/needle.svg?branch=master)](https://travis-ci.com/uber/needle?branch=master)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Needle is a dependency injection (DI) system for Swift. Unlike other DI frameworks, such as [Cleanse](https://github.com/square/Cleanse), [Swinject](https://github.com/Swinject/Swinject), Needle encourages **hierarchical DI structure and utilizes code generation to ensure compile-time safety**. This allows us to develop our apps and make code changes with confidence. **If it compiles, it works.** In this aspect, Needle is more similar to [Dagger for the JVM](https://google.github.io/dagger/).

Needle aims to achieve the following primary goals:
1. Provide high reliability by ensuring dependency injection code is compile-time safe.
2. Ensure code generation is highly performant even when used with multi-million-line codebases.
3. Be compatible with all iOS application architectures, including RIBs, MVx etc.

## The gist

Using Needle to write DI code for your application is easy and compile-time safe. Each dependency scope is defined by a `Component`. And its dependencies are encapsulated in a Swift `protocol`. The two are linked together using Swift generics.

```swift
/// This protocol encapsulates the dependencies acquired from ancestor scopes.
protocol MyDependency: Dependency {
    /// These are objects obtained from ancestor scopes, not newly introduced at this scope.
    var chocolate: Food { get }
    var milk: Food { get }
}

/// This class defines a new dependency scope that can acquire dependencies from ancestor scopes
/// via its dependency protocol, provide new objects on the DI graph by declaring properties,
/// and instantiate child scopes.
class MyComponent: Component<MyDependency> {

    /// A new object, hotChocolate, is added to the dependency graph. Child scope(s) can then
    /// acquire this via their dependency protocol(s).
    var hotChocolate: Drink {
        return HotChocolate(dependency.chocolate, dependency.milk)
    }

    /// A child scope is always instantiated by its parent(s) scope(s).
    var myChildComponent: MyChildComponent {
        return MyChildComponent(parent: self)
    }
}
```

This is pretty much it, when writing DI code with Needle. As you can see, everything is real, compilable Swift code. No fragile comments or "annotations". To quickly recap, the three key concepts here are dependency protocol, component and instantiation of child component(s). Please refer to the [Getting started with Needle](#getting-started-with-needle) section below for more detailed explanations and advanced topics.

## Getting started with Needle

Using and integrating with Needle has two steps. Each of the following steps has detailed instructions and explanations in the linked documents.

1. [Integrate Needle's code generator with your Swift project](./GENERATOR.md).
2. [Write application DI code following NeedleFoundation's API](./API.md).

## Installation

Needle has two parts, the `NeedleFoundation` framework and the executable code generator. Both parts need to be integrated with your Swift project in order to use Needle as your DI system.

### Install `NeedleFoundation` framework

#### Using [Carthage](https://github.com/Carthage/Carthage)

Please follow the standard [Carthage installation process](https://github.com/Carthage/Carthage#quick-start) to integrate the `NeedleFoundation` framework with your Swift project.
```
github "https://github.com/uber/needle.git" ~> VERSION_OF_NEEDLE
```

#### Using [Swift Package Manager](https://github.com/apple/swift-package-manager)

Please specify Needle as a dependency via the standard [Swift Package Manager package definition process](https://github.com/apple/swift-package-manager/blob/master/Documentation/Usage.md) to integrate the `NeedleFoundation` framework with your Swift project.
```
dependencies: [
    .package(url: "https://github.com/uber/needle.git", .upToNextMajor(from: "VERSION_NUMBER")),
],
targets: [
    .target(
        name: "YOUR_MODULE",
        dependencies: [
            "NeedleFoundation",
        ]),
],
```

#### Using [CocoaPods](https://github.com/CocoaPods/CocoaPods)

Please follow the standard pod integration process and use `NeedleFoundation` pod.

### Install code generator

#### Using Swift Package Manager plugins (recommended, no separate installation)

If the `NeedleFoundation` framework is integrated via Swift Package Manager, the code generator is already bundled with the package — no Homebrew or manual installation is needed. Two plugins are provided:

**Build tool plugin** — runs the generator automatically before each build of the target it is attached to. The generated file is created in the build directory and compiled into the target for you: nothing to run manually, nothing to commit. See the step-by-step guide below.

**Command plugin** — run the generator manually and commit the generated file, mirroring the classic workflow. See [Using the command plugin](#using-the-command-plugin).

##### Running Needle via `NeedleBuildToolPlugin`

*In a Swift package:* add the plugin to the application target in `Package.swift`:

```swift
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/uber/needle.git", .upToNextMajor(from: "VERSION_NUMBER")),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [.product(name: "NeedleFoundation", package: "needle")],
            plugins: [.plugin(name: "NeedleBuildToolPlugin", package: "needle")]),
    ]
)
```

*In an Xcode project:*

1. Add the needle package via *File → Add Package Dependencies…* and link `NeedleFoundation` to your app target.
2. Open the app target's *Build Phases* tab, expand *Run Build Tool Plug-ins*, press *+* and add `NeedleBuildToolPlugin`.
3. Build once; when Xcode asks about the plugin, choose *Trust & Enable*.

That's it — declare your components as usual and call `registerProviderFactories()` at startup. The function is generated into the same module, so no extra import is needed:

```swift
import NeedleFoundation

protocol RootDependency: Dependency {
    var apiClient: APIClient { get }
}

class AppComponent: BootstrapComponent {
    // Provider properties must be `public`, otherwise the generator
    // does not consider them when resolving dependencies.
    public var apiClient: APIClient {
        return shared { APIClient() }
    }

    var rootComponent: RootComponent {
        return RootComponent(parent: self)
    }
}

class RootComponent: Component<RootDependency> {}
```

```swift
@main
struct MyApp: App {
    init() {
        registerProviderFactories()
    }
    // ...
}
```

Good to know:

- The plugin parses the sources of the target it is attached to plus those of its dependency targets in the same package (or, for Xcode projects, its dependency targets in the same project). Attach the plugin to the application target only — dependency modules are picked up from there automatically.
- External packages are never parsed. If your components live in a separate package, use the command plugin below and pass the paths explicitly.
- Regeneration is incremental: the generator only re-runs when one of the parsed Swift files actually changes.
- If a dependency cannot be resolved, the build fails with the generator's `Could not find a provider for …` warnings in the build log — the most common cause is a provider property that is not `public`.

##### Using the command plugin

Run the generator manually and commit the generated file, mirroring the classic workflow:

```
swift package --allow-writing-to-package-directory needle \
    generate Sources/App/NeedleGenerated.swift Sources/App
```

All regular generator arguments are supported; run `swift package needle --help` for the full list.

#### Using [Carthage](https://github.com/Carthage/Carthage)

If Carthage is used to integrate  the `NeedleFoundation` framework, then a copy of the code generator executable of the corresponding version is already downloaded in the Carthage folder. It can be found at `Carthage/Checkouts/needle/Generator/bin/needle.artifactbundle/needle/bin/needle`.

#### Using [Homebrew](https://github.com/Homebrew/brew)

Regardless of how the `NeedleFoundation` framework is integrated into your project, the generator can always be installed via [Homebrew](https://github.com/Homebrew/brew).
```
brew install needle
```

## [Why use dependency injection?](./WHY_DI.md)

The linked document uses a somewhat real example to explain what the dependency injection pattern is, and its benefits.

## Translations

- [Korean](./Documents/ko_KR/README.md)

## Related projects

If you like Needle, check out other related open source projects from our team:
- [Swift Concurrency](https://github.com/uber/swift-concurrency): a set of concurrency utility classes used by Uber, inspired by the equivalent [java.util.concurrent](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/package-summary.html) package classes.
- [Swift Abstract Class](https://github.com/uber/swift-abstract-class): a light-weight library along with an executable that enables compile-time safe abstract class development for Swift projects.
- [Swift Common](https://github.com/uber/swift-common): common libraries used by this set of Swift open source projects.

## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fuber%2Fswift-concurrency.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fuber%2Fswift-concurrency?ref=badge_large)
