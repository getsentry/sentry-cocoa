import XCTest

// We need to know whether Apple changes the NSURLSessionTask implementation.
class SentryNSURLSessionTaskSearchTests: XCTestCase {

    func test_URLSessionTask_ByIosVersion() {
        let classes = SentryNSURLSessionTaskSearch.urlSessionTaskClassesToTrack()

        XCTAssertEqual(classes.count, 1)
        XCTAssertTrue(classes.first === URLSessionTask.self)
    }

#if compiler(>=6.1)
    func testURLSessionTask_whenUsingClassicLoader_shouldUseTrackedClasses() throws {
        let configuration = try loaderConfiguration(usesClassicLoadingMode: true)
        let classes = urlSessionTaskClassesToTrack(configuration: configuration)

        XCTAssertEqual(classes.count, 1)
        XCTAssertTrue(classes.first === URLSessionTask.self)
    }

    func testURLSessionTask_whenUsingNewLoader_shouldMatchPlatformTrackingSupport() throws {
        let configuration = try loaderConfiguration(usesClassicLoadingMode: false)
        let classes = urlSessionTaskClassesToTrack(configuration: configuration)

#if os(watchOS)
        XCTAssertEqual(classes.count, 1)
        XCTAssertTrue(classes.first === URLSessionTask.self)
#else
        XCTAssertTrue(
            classes.isEmpty,
            "The new loader now exposes a setState: implementation. Reevaluate network tracking support."
        )
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
