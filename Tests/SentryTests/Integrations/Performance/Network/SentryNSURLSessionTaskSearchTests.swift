import XCTest

// We need to know whether Apple changes the NSURLSessionTask implementation.
class SentryNSURLSessionTaskSearchTests: XCTestCase {

    func test_URLSessionTask_ByIosVersion() {
        let classes = SentryNSURLSessionTaskSearch.urlSessionTaskClassesToTrack()

        XCTAssertEqual(classes.count, 1)
        XCTAssertTrue(classes.first === URLSessionTask.self)
    }

    // MARK: - NSURLSession class hierarchy validation tests
    //
    // Based on testing, NSURLSession implements dataTaskWithRequest:completionHandler:
    // and dataTaskWithURL:completionHandler: directly on the base class.
    //
    // The swizzling code relies on this by swizzling [NSURLSession class] directly
    // rather than doing runtime discovery. These tests verify that assumption
    // still holds — if Apple ever moves these methods, these tests
    // will fail and we'll know to update the swizzling approach.

    func test_URLSessionDataTaskWithRequest_ByIosVersion() {
        let selector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URLRequest, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        assertNSURLSessionImplementsDirectly(selector: selector, selectorName: "dataTaskWithRequest:completionHandler:")
    }

    func test_URLSessionDataTaskWithURL_ByIosVersion() {
        let selector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URL, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        assertNSURLSessionImplementsDirectly(selector: selector, selectorName: "dataTaskWithURL:completionHandler:")
    }

    // MARK: - Helper

    /// Walks the class hierarchy for sessions created with default and ephemeral
    /// configurations and asserts that no subclass overrides `selector`.
    private func assertNSURLSessionImplementsDirectly(selector: Selector, selectorName: String) {
        let baseClass: AnyClass = URLSession.self

        // The base class must implement the method.
        XCTAssertNotNil(
            class_getInstanceMethod(baseClass, selector),
            "URLSession should implement \(selectorName)"
        )

        // Check sessions created with each relevant configuration.
        let configs: [URLSessionConfiguration] = [
            .default,
            .ephemeral
        ]

        for config in configs {
            let session = URLSession(configuration: config)
            let sessionClass: AnyClass = type(of: session)

            defer { session.invalidateAndCancel() }

            if sessionClass === baseClass {
                continue
            }

            // If Apple returns a subclass, it must NOT provide its own
            // implementation — it should inherit from URLSession.
            let subMethod = class_getInstanceMethod(sessionClass, selector)
            let baseMethod = class_getInstanceMethod(baseClass, selector)

            if let subMethod, let baseMethod {
                let subIMP = method_getImplementation(subMethod)
                let baseIMP = method_getImplementation(baseMethod)
                XCTAssertEqual(
                    subIMP, baseIMP,
                    "\(NSStringFromClass(sessionClass)) overrides \(selectorName) with an unexpected IMP — "
                    + "Verify swizzling in SentrySwizzleWrapperHelper is correct for dataTasks."
                )
            }
        }
    }
}
