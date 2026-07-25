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
import XCTest
@testable import NeedleFoundation

class RegistryConcurrencyTests: XCTestCase {

    override func setUp() {
        super.setUp()

        __DependencyProviderRegistry.instance.registerDependencyProviderFactory(for: "^->ConcurrentAppComponent") { component in
            return EmptyDependencyProvider(component: component)
        }
        __DependencyProviderRegistry.instance.registerDependencyProviderFactory(for: "^->ConcurrentAppComponent->ConcurrentChildComponent") { _ in
            return ConcurrentChildDependencyProvider()
        }
    }

    func test_registry_concurrentRegisterResolveUnregister() {
        DispatchQueue.concurrentPerform(iterations: 500) { i in
            let path = "^->ConcurrentAppComponent->TransientComponent\(i)"
            let marker = ConcurrentChildDependencyProvider()
            __DependencyProviderRegistry.instance.registerDependencyProviderFactory(for: path) { _ in
                return marker
            }

            let appComponent = ConcurrentAppComponent()
            #if !NEEDLE_DYNAMIC
            // Exercise the full component-init resolution path through the
            // registry, while other threads register and unregister factories.
            XCTAssertTrue(appComponent.childComponent.dependency is ConcurrentChildDependencyProvider)
            #endif

            // The register -> lookup -> invoke round-trip must yield this
            // iteration's marker, not a factory registered by another thread.
            if let factory = __DependencyProviderRegistry.instance.dependencyProviderFactory(for: path) {
                XCTAssertTrue(factory(appComponent) === marker)
            } else {
                XCTFail("Factory registered for \(path) was not found")
            }

            __DependencyProviderRegistry.instance.unregisterDependencyProviderFactory(for: path)
            XCTAssertNil(__DependencyProviderRegistry.instance.dependencyProviderFactory(for: path))
        }
    }

    func test_shared_concurrentAccess_returnsSingleInstance() {
        // `shared` is documented as thread-safe on a single component instance,
        // so sharing the component across threads here is intentional. The
        // first `shared` access happens inside the concurrent section, so the
        // check-then-create path itself runs under contention.
        nonisolated(unsafe) let appComponent = ConcurrentAppComponent()
        let tokens = ConcurrentCollector<SharedToken>()
        DispatchQueue.concurrentPerform(iterations: 500) { _ in
            let token = unsafe appComponent.sharedToken
            tokens.append(token)
        }

        let collected = tokens.snapshot()
        XCTAssertEqual(collected.count, 500)
        guard let first = collected.first else {
            XCTFail("No shared instances were collected")
            return
        }
        XCTAssertTrue(collected.allSatisfy { $0 === first })
    }
}

/// Thread-safe accumulator for values produced inside `concurrentPerform`.
private final class ConcurrentCollector<Element>: @unchecked Sendable {

    private let lock = NSLock()
    private var elements = [Element]()

    func append(_ element: Element) {
        lock.lock()
        defer {
            lock.unlock()
        }
        elements.append(element)
    }

    func snapshot() -> [Element] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return elements
    }
}

final class ConcurrentAppComponent: BootstrapComponent {

    var childComponent: ConcurrentChildComponent {
        return ConcurrentChildComponent(parent: self)
    }

    var sharedToken: SharedToken {
        return shared { SharedToken() }
    }
}

final class SharedToken: Sendable {}

protocol ConcurrentChildDependency: AnyObject {}

final class ConcurrentChildComponent: Component<ConcurrentChildDependency> {}

final class ConcurrentChildDependencyProvider: ConcurrentChildDependency, Sendable {}
