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
    // still holds — if Apple ever moves these methods to a subclass, these tests
    // will fail and we'll know to update the swizzling approach.

    func test_URLSession_isNotClassCluster_dataTaskWithRequest() {
        let selector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URLRequest, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        assertNSURLSessionImplementsDirectly(selector: selector, selectorName: "dataTaskWithRequest:completionHandler:")
    }

    func test_URLSession_isNotClassCluster_dataTaskWithURL() {
        let selector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URL, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        assertNSURLSessionImplementsDirectly(selector: selector, selectorName: "dataTaskWithURL:completionHandler:")
    }

    // MARK: - dataTaskWithURL: / dataTaskWithRequest: independence
    //
    // We swizzle both dataTaskWithRequest:completionHandler: and
    // dataTaskWithURL:completionHandler: because they are independent
    // implementations — dataTaskWithURL: does NOT dispatch to
    // dataTaskWithRequest: via objc_msgSend.
    //
    // If this test ever fails, Apple has changed the internal dispatch so
    // one calls through to the other. In that case, remove the redundant
    // swizzle and add a deduplication guard to avoid double-capture.

    func test_dataTaskWithURL_doesNotCallThrough_dataTaskWithRequest() {
        assertNoCallThrough(
            from: NSSelectorFromString("dataTaskWithURL:completionHandler:"),
            to: NSSelectorFromString("dataTaskWithRequest:completionHandler:"),
            call: { session in
                let url = URL(string: "https://example.com")!
                let task = session.dataTask(with: url) { _, _, _ in }
                task.cancel()
            }
        )
    }

    func test_dataTaskWithRequest_doesNotCallThrough_dataTaskWithURL() {
        assertNoCallThrough(
            from: NSSelectorFromString("dataTaskWithRequest:completionHandler:"),
            to: NSSelectorFromString("dataTaskWithURL:completionHandler:"),
            call: { session in
                let request = URLRequest(url: URL(string: "https://example.com")!)
                let task = session.dataTask(with: request) { _, _, _ in }
                task.cancel()
            }
        )
    }

    /// Temporarily replaces the IMP of `targetSelector` with one that increments
    /// a counter, then invokes `call` (which should trigger `sourceSelector`).
    /// Asserts the counter stays at 0 — meaning `sourceSelector` does not
    /// internally dispatch to `targetSelector` via objc_msgSend.
    private func assertNoCallThrough(
        from sourceSelector: Selector,
        to targetSelector: Selector,
        call: (URLSession) -> Void
    ) {
        guard let method = class_getInstanceMethod(URLSession.self, targetSelector) else {
            XCTFail("URLSession should implement \(targetSelector)")
            return
        }

        let originalIMP = method_getImplementation(method)
        defer { method_setImplementation(method, originalIMP) }

        var hitCount = 0

        let replacementBlock: @convention(block) (NSObject, AnyObject, Any?) -> AnyObject = { obj, arg, handler in
            hitCount += 1
            typealias Fn = @convention(c) (NSObject, Selector, AnyObject, Any?) -> AnyObject
            let original = unsafeBitCast(originalIMP, to: Fn.self)
            return original(obj, targetSelector, arg, handler)
        }

        method_setImplementation(method, imp_implementationWithBlock(replacementBlock))

        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }

        call(session)

        XCTAssertEqual(
            hitCount, 0,
            "\(sourceSelector) called through to \(targetSelector). "
            + "These methods are no longer independent — remove the redundant swizzle "
            + "in SentrySwizzleWrapperHelper and add a deduplication guard."
        )
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
