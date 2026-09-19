import XCTest

// We need to know whether Apple changes the NSURLSessionTask implementation.
class SentryNSURLSessionTaskSearchTests: XCTestCase {

    func test_URLSessionTask_ByIosVersion() {
        let classes = SentryNSURLSessionTaskSearch.urlSessionTaskClassesToTrack()

        XCTAssertEqual(classes.count, 1)
        XCTAssertTrue(classes.first === URLSessionTask.self)
    }

#if compiler(>=6.1)
    func testURLSessionTasks_whenUsingClassicLoader_shouldInheritFromURLSessionTask() throws {
        // -- Arrange --
        let configuration = try loaderConfiguration(usesClassicLoadingMode: true)

        // -- Act --
        let hierarchies = try taskClassHierarchies(configuration: configuration)

        // -- Assert --
        for hierarchy in hierarchies {
            XCTAssertTrue(
                hierarchy.contains { $0 === URLSessionTask.self },
                "Classic loader task hierarchy changed: \(hierarchy.map(NSStringFromClass)). "
                    + "Reevaluate SentryDefaultNetworkTracker.isNewLoaderTask."
            )
        }
    }

    func testURLSessionTasks_whenUsingNewLoader_shouldMatchPlatformTaskInheritance() throws {
        // -- Arrange --
        let configuration = try loaderConfiguration(usesClassicLoadingMode: false)

        // -- Act --
        let hierarchies = try taskClassHierarchies(configuration: configuration)

        // -- Assert --
        for hierarchy in hierarchies {
            let inheritsFromURLSessionTask = hierarchy.contains { $0 === URLSessionTask.self }
            let message = "New loader task hierarchy changed: \(hierarchy.map(NSStringFromClass)). "
                + "Reevaluate SentryDefaultNetworkTracker.isNewLoaderTask."
#if os(watchOS)
            XCTAssertTrue(inheritsFromURLSessionTask, message)
#else
            XCTAssertFalse(inheritsFromURLSessionTask, message)
#endif
        }
    }

    func testURLSessionTask_whenUsingClassicLoader_shouldUseTrackedClasses() throws {
        let configuration = try loaderConfiguration(usesClassicLoadingMode: true)
        let classes = urlSessionTaskClassesToTrack(configuration: configuration)

        XCTAssertEqual(classes.count, 1)
        XCTAssertTrue(classes.first === URLSessionTask.self)
    }

    func testURLSessionTask_whenUsingNewLoader_shouldMatchPlatformTrackingSupport() throws {
        // -- Arrange --
        let configuration = try loaderConfiguration(usesClassicLoadingMode: false)
#if !os(watchOS)
        let selector = NSSelectorFromString("setState:")
        let classicMethod = try XCTUnwrap(class_getInstanceMethod(URLSessionTask.self, selector))
        let classicImplementation = method_getImplementation(classicMethod)
#endif

        // -- Act --
        let classes = urlSessionTaskClassesToTrack(configuration: configuration)

        // -- Assert --
#if os(watchOS)
        XCTAssertEqual(classes.count, 1)
        XCTAssertTrue(classes.first === URLSessionTask.self)
#else
        // Network.framework copies swizzled URLSessionTask methods when the new loader first
        // initializes. A copied setter is not a native state transition hook, so its presence
        // depends on whether the SDK started before the first new-loader session was created.
        for taskClass in classes {
            let method = try XCTUnwrap(class_getInstanceMethod(taskClass, selector))
            XCTAssertEqual(
                method_getImplementation(method),
                classicImplementation,
                "The new loader now exposes an independent setState: implementation on \(NSStringFromClass(taskClass)). "
                    + "Reevaluate network tracking support."
            )
        }
#endif
    }

#endif

    // MARK: - NSURLSession class hierarchy validation tests
    //
    // Based on testing, NSURLSession implements dataTaskWithRequest:completionHandler:
    // and dataTaskWithURL:completionHandler: directly on the base class for the classic loader.
    //
    // The classic loader inherits these methods from URLSession, while the new loader overrides
    // them in a private subclass. These tests pin both runtime shapes because instrumentation must
    // install its public factory-method swizzles on the class that implements each loader.

#if compiler(>=6.1)
    func test_URLSessionDataTaskWithRequest_ByIosVersion() throws {
        let selector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URLRequest, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)

        try assertClassicLoaderInheritsURLSessionImplementation(
            selector: selector,
            selectorName: "dataTaskWithRequest:completionHandler:"
        )
        try assertNewLoaderURLSessionImplementation(
            selector: selector,
            selectorName: "dataTaskWithRequest:completionHandler:"
        )
    }

    func test_URLSessionDataTaskWithURL_ByIosVersion() throws {
        let selector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URL, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)

        try assertClassicLoaderInheritsURLSessionImplementation(
            selector: selector,
            selectorName: "dataTaskWithURL:completionHandler:"
        )
        try assertNewLoaderURLSessionImplementation(
            selector: selector,
            selectorName: "dataTaskWithURL:completionHandler:"
        )
    }

#endif

    // MARK: - Helpers

#if compiler(>=6.1)

    private func taskClassHierarchies(configuration: URLSessionConfiguration) throws -> [[AnyClass]] {
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let tasks: [URLSessionTask] = [
            session.dataTask(with: url),
            session.downloadTask(with: url),
            session.uploadTask(with: URLRequest(url: url), from: Data())
        ]
        defer {
            tasks.forEach { $0.cancel() }
            session.finishTasksAndInvalidate()
        }

        // Swift casts accept both loaders' tasks as URLSessionTask, so inspect the actual
        // Objective-C superclass chain used by SentryDefaultNetworkTracker.isNewLoaderTask.
        return tasks.map { task in
            var hierarchy = [AnyClass]()
            var currentClass: AnyClass? = type(of: task)
            while let candidate = currentClass {
                hierarchy.append(candidate)
                currentClass = class_getSuperclass(candidate)
            }
            return hierarchy
        }
    }

    private func assertClassicLoaderInheritsURLSessionImplementation(
        selector: Selector,
        selectorName: String
    ) throws {
        let baseMethod = try XCTUnwrap(
            class_getInstanceMethod(URLSession.self, selector),
            "URLSession should implement \(selectorName)"
        )
        let configuration = try loaderConfiguration(usesClassicLoadingMode: true)
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let sessionMethod = try XCTUnwrap(class_getInstanceMethod(type(of: session), selector))
        XCTAssertEqual(
            method_getImplementation(sessionMethod),
            method_getImplementation(baseMethod),
            "The classic loader should inherit \(selectorName) from URLSession."
        )
    }

    private func assertNewLoaderURLSessionImplementation(
        selector: Selector,
        selectorName: String
    ) throws {
        let baseMethod = try XCTUnwrap(
            class_getInstanceMethod(URLSession.self, selector),
            "URLSession should implement \(selectorName)"
        )
        let configuration = try loaderConfiguration(usesClassicLoadingMode: false)
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let sessionMethod = try XCTUnwrap(class_getInstanceMethod(type(of: session), selector))
#if os(watchOS)
        XCTAssertEqual(
            method_getImplementation(sessionMethod),
            method_getImplementation(baseMethod),
            "The watchOS new loader should inherit \(selectorName) from URLSession."
        )
#else
        XCTAssertNotEqual(
            method_getImplementation(sessionMethod),
            method_getImplementation(baseMethod),
            "The new loader now inherits \(selectorName). Reevaluate response capture support."
        )
#endif
    }

    private func loaderConfiguration(usesClassicLoadingMode: Bool) throws -> URLSessionConfiguration {
        guard #available(macOS 15.4, iOS 18.4, tvOS 18.4, watchOS 11.4, visionOS 2.4, *) else {
            throw XCTSkip("The selected OS does not support choosing the URLSession HTTP loader.")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.usesClassicLoadingMode = usesClassicLoadingMode
        return configuration
    }

    private func urlSessionTaskClassesToTrack(configuration: URLSessionConfiguration) -> [AnyClass] {
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: URL(string: "https://example.com")!)
        defer {
            task.cancel()
            session.finishTasksAndInvalidate()
        }

        var currentClass: AnyClass = type(of: task)
        var classes = [AnyClass]()
        let setStateSelector = NSSelectorFromString("setState:")

        while let method = class_getInstanceMethod(currentClass, setStateSelector) {
            guard let superclass = class_getSuperclass(currentClass) else {
                break
            }

            let superclassImplementation = class_getInstanceMethod(superclass, setStateSelector)
                .map(method_getImplementation)
            if method_getImplementation(method) != superclassImplementation {
                classes.append(currentClass)
            }
            currentClass = superclass
        }

        return classes
    }
#endif
}
