@testable import Sentry
import Foundation
import ObjectiveC
import XCTest

final class SentryTypedSwizzleURLSessionTasksTests: XCTestCase {

    func testInstanceMethod_whenTaskStateMethod_shouldReplaceArgument() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleTaskStateTarget()

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleTaskStateTarget.self,
            method: .urlSessionTaskState(TypedSwizzleTaskStateTarget.self),
            mode: .always,
            key: key
        ) { _, state, original in
            XCTAssertEqual(state, .running)
            original(.completed)
        }
        target.setState(.running)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(target.receivedState, .completed)
    }

    func testInstanceMethod_whenDownloadTaskMethod_shouldWrapCompletionAndReturnOriginalResult() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleTransferTaskTarget()
        let url = URL(string: "https://example.com/original")!
        let replacementURL = URL(string: "https://example.com/replacement")!
        var completionLocation: URL?
        let method = SentrySwizzleMethod<TypedSwizzleTransferTaskTarget, SentryDownloadTaskURLArguments, URLSessionDownloadTask>(
            selector: #selector(TypedSwizzleTransferTaskTarget.makeDownloadTask(_:completionHandler:)),
            receiver: TypedSwizzleTransferTaskTarget.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .block])
        )

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleTransferTaskTarget.self,
            method: method,
            mode: .always,
            key: key
        ) { _, receivedURL, completionHandler, original in
            XCTAssertEqual(receivedURL, url)
            let wrappedCompletion: SentryDownloadTaskCompletionHandler = { _, response, error in
                completionHandler?(replacementURL, response, error)
            }
            return original(replacementURL, wrappedCompletion)
        }
        let result = target.makeDownloadTask(url) { location, _, _ in
            completionLocation = location
        }

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertIdentical(result, target.downloadTask)
        XCTAssertEqual(target.receivedURL, replacementURL)
        XCTAssertEqual(completionLocation, replacementURL)
    }

    func testInstanceMethod_whenUploadTaskMethod_shouldWrapCompletionAndReturnOriginalResult() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleTransferTaskTarget()
        let request = URLRequest(url: URL(string: "https://example.com/original")!)
        let replacementRequest = URLRequest(url: URL(string: "https://example.com/replacement")!)
        let data = Data("original".utf8)
        let replacementData = Data("replacement".utf8)
        var completionData: Data?
        let method = SentrySwizzleMethod<TypedSwizzleTransferTaskTarget, SentryUploadTaskDataArguments, URLSessionUploadTask>(
            selector: #selector(TypedSwizzleTransferTaskTarget.makeUploadTask(_:data:completionHandler:)),
            receiver: TypedSwizzleTransferTaskTarget.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object, .block])
        )

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleTransferTaskTarget.self,
            method: method,
            mode: .always,
            key: key
        ) { _, receivedRequest, receivedData, completionHandler, original in
            XCTAssertEqual(receivedRequest, request)
            XCTAssertEqual(receivedData, data)
            return original(replacementRequest, replacementData, completionHandler)
        }
        let result = target.makeUploadTask(request, data: data) { result, _, _ in
            completionData = result
        }

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertIdentical(result, target.uploadTask)
        XCTAssertEqual(target.receivedRequest, replacementRequest)
        XCTAssertEqual(target.receivedData, replacementData)
        XCTAssertEqual(completionData, replacementData)
    }

    func testInstanceMethod_whenRequestDataTaskMethod_shouldWrapCompletionAndReturnOriginalResult() throws {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleDataTaskTarget()
        let request = URLRequest(url: URL(string: "https://example.com/original")!)
        let replacementRequest = URLRequest(url: URL(string: "https://example.com/replacement")!)
        var completionData: Data?
        let method = SentrySwizzleMethod<TypedSwizzleDataTaskTarget, SentryDataTaskRequestArguments, URLSessionDataTask>(
            selector: #selector(TypedSwizzleDataTaskTarget.makeTaskWithRequest(_:completionHandler:)),
            receiver: TypedSwizzleDataTaskTarget.self,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleDataTaskTarget.self,
            method: method,
            mode: .always,
            key: key
        ) { _, receivedRequest, completionHandler, original in
            XCTAssertEqual(receivedRequest, request)
            let wrappedCompletion: SentryDataTaskCompletionHandler = { _, response, error in
                completionHandler?(Data("wrapped".utf8), response, error)
            }
            return original(replacementRequest, wrappedCompletion)
        }
        let result = target.makeTaskWithRequest(request) { data, _, _ in
            completionData = data
        }

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertIdentical(result, target.task)
        XCTAssertEqual(target.receivedRequest, replacementRequest)
        XCTAssertEqual(completionData, Data("wrapped".utf8))
    }

    func testInstanceMethod_whenURLDataTaskMethod_shouldReplaceURLAndReturnOriginalResult() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleDataTaskTarget()
        let url = URL(string: "https://example.com/original")!
        let replacementURL = URL(string: "https://example.com/replacement")!
        let method = SentrySwizzleMethod<TypedSwizzleDataTaskTarget, SentryDataTaskURLArguments, URLSessionDataTask>(
            selector: #selector(TypedSwizzleDataTaskTarget.makeTaskWithURL(_:completionHandler:)),
            receiver: TypedSwizzleDataTaskTarget.self,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleDataTaskTarget.self,
            method: method,
            mode: .always,
            key: key
        ) { _, receivedURL, completionHandler, original in
            XCTAssertEqual(receivedURL, url)
            return original(replacementURL, completionHandler)
        }
        let result = target.makeTaskWithURL(url, completionHandler: nil)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertIdentical(result, target.task)
        XCTAssertEqual(target.receivedURL, replacementURL)
    }

    func testInstanceMethod_whenTaskStateReceiverCastFails_shouldStillCallOriginal() throws {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let selector = #selector(TypedSwizzleStateMismatchBase.setState(_:))
        var interceptorCallCount = 0
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleStateMismatchChild.self,
            method: .urlSessionTaskState(TypedSwizzleStateMismatchChild.self),
            mode: .always,
            key: key
        ) { _, _, original in
            interceptorCallCount += 1
            original(.completed)
        }
        XCTAssertTrue(installed)

        // Invoke the installed trampoline directly with a receiver whose type is the superclass,
        // forcing the `receiver as? Receiver` cast to the subclass to fail.
        let imp = try XCTUnwrap(class_getMethodImplementation(TypedSwizzleStateMismatchChild.self, selector))
        typealias StateMethod = @convention(c) (AnyObject, Selector, URLSessionTask.State) -> Void
        let trampoline = unsafeBitCast(imp, to: StateMethod.self)
        let mismatchedReceiver = TypedSwizzleStateMismatchBase()

        // -- Act --
        trampoline(mismatchedReceiver, selector, .running)

        // -- Assert --
        XCTAssertEqual(interceptorCallCount, 0, "Interceptor must not run for a mismatched receiver")
        XCTAssertEqual(mismatchedReceiver.receivedState, .running, "Original must still be invoked with the received state when the receiver cast fails")
    }

    func testInstanceMethod_whenRequestDataTaskReceiverCastFails_shouldStillCallOriginal() throws {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let selector = #selector(TypedSwizzleDataTaskMismatchBase.makeTaskWithRequest(_:completionHandler:))
        var interceptorCallCount = 0
        let method = SentrySwizzleMethod<TypedSwizzleDataTaskMismatchChild, SentryDataTaskRequestArguments, URLSessionDataTask>(
            selector: selector,
            receiver: TypedSwizzleDataTaskMismatchChild.self,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleDataTaskMismatchChild.self,
            method: method,
            mode: .always,
            key: key
        ) { _, _, _, original in
            interceptorCallCount += 1
            return original(URLRequest(url: URL(string: "https://example.com/replacement")!), nil)
        }
        XCTAssertTrue(installed)

        // Invoke the installed trampoline directly with a receiver whose type is the superclass,
        // forcing the `receiver as? Receiver` cast to the subclass to fail.
        let imp = try XCTUnwrap(class_getMethodImplementation(TypedSwizzleDataTaskMismatchChild.self, selector))
        typealias RequestMethod = @convention(c) (AnyObject, Selector, URLRequest, SentryDataTaskCompletionHandler?) -> URLSessionDataTask
        let trampoline = unsafeBitCast(imp, to: RequestMethod.self)
        let mismatchedReceiver = TypedSwizzleDataTaskMismatchBase()
        let request = URLRequest(url: URL(string: "https://example.com/original")!)

        // -- Act --
        let result = trampoline(mismatchedReceiver, selector, request, nil)

        // -- Assert --
        XCTAssertEqual(interceptorCallCount, 0, "Interceptor must not run for a mismatched receiver")
        XCTAssertEqual(mismatchedReceiver.receivedRequest, request, "Original must still be invoked with the received request when the receiver cast fails")
        XCTAssertIdentical(result, mismatchedReceiver.task)
    }

    func testInstanceMethod_whenURLDataTaskReceiverCastFails_shouldStillCallOriginal() throws {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let selector = #selector(TypedSwizzleDataTaskMismatchBase.makeTaskWithURL(_:completionHandler:))
        var interceptorCallCount = 0
        let method = SentrySwizzleMethod<TypedSwizzleDataTaskMismatchChild, SentryDataTaskURLArguments, URLSessionDataTask>(
            selector: selector,
            receiver: TypedSwizzleDataTaskMismatchChild.self,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleDataTaskMismatchChild.self,
            method: method,
            mode: .always,
            key: key
        ) { _, _, _, original in
            interceptorCallCount += 1
            return original(URL(string: "https://example.com/replacement")!, nil)
        }
        XCTAssertTrue(installed)

        // Invoke the installed trampoline directly with a receiver whose type is the superclass,
        // forcing the `receiver as? Receiver` cast to the subclass to fail.
        let imp = try XCTUnwrap(class_getMethodImplementation(TypedSwizzleDataTaskMismatchChild.self, selector))
        typealias URLMethod = @convention(c) (AnyObject, Selector, URL, SentryDataTaskCompletionHandler?) -> URLSessionDataTask
        let trampoline = unsafeBitCast(imp, to: URLMethod.self)
        let mismatchedReceiver = TypedSwizzleDataTaskMismatchBase()
        let url = URL(string: "https://example.com/original")!

        // -- Act --
        let result = trampoline(mismatchedReceiver, selector, url, nil)

        // -- Assert --
        XCTAssertEqual(interceptorCallCount, 0, "Interceptor must not run for a mismatched receiver")
        XCTAssertEqual(mismatchedReceiver.receivedURL, url, "Original must still be invoked with the received URL when the receiver cast fails")
        XCTAssertIdentical(result, mismatchedReceiver.task)
    }

    func testInstanceMethod_whenTaskStateValidationFails_shouldNotInstall() {
        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleURLSessionValidationTarget.self,
            method: .urlSessionTaskState(TypedSwizzleURLSessionValidationTarget.self),
            mode: .always,
            key: SentryTypedSwizzle.Key()
        ) { _, _, original in
            original(.completed)
        }

        // -- Assert --
        XCTAssertFalse(installed)
    }

    func testInstanceMethod_whenRequestDataTaskValidationFails_shouldNotInstall() {
        // -- Arrange --
        let method = SentrySwizzleMethod<TypedSwizzleURLSessionValidationTarget, SentryDataTaskRequestArguments, URLSessionDataTask>(
            selector: NSSelectorFromString("missingDataTaskWithRequest:completionHandler:"),
            receiver: TypedSwizzleURLSessionValidationTarget.self,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleURLSessionValidationTarget.self,
            method: method,
            mode: .always,
            key: SentryTypedSwizzle.Key()
        ) { _, _, _, original in
            original(URLRequest(url: URL(string: "https://example.com")!), nil)
        }

        // -- Assert --
        XCTAssertFalse(installed)
    }

    func testInstanceMethod_whenURLDataTaskValidationFails_shouldNotInstall() {
        // -- Arrange --
        let method = SentrySwizzleMethod<TypedSwizzleURLSessionValidationTarget, SentryDataTaskURLArguments, URLSessionDataTask>(
            selector: NSSelectorFromString("missingDataTaskWithURL:completionHandler:"),
            receiver: TypedSwizzleURLSessionValidationTarget.self,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleURLSessionValidationTarget.self,
            method: method,
            mode: .always,
            key: SentryTypedSwizzle.Key()
        ) { _, _, _, original in
            original(URL(string: "https://example.com")!, nil)
        }

        // -- Assert --
        XCTAssertFalse(installed)
    }
}

private final class TypedSwizzleTransferTaskTarget: NSObject {
    let downloadTask = URLSession.shared.downloadTask(with: URL(string: "https://example.com")!)
    let uploadTask = URLSession.shared.uploadTask(
        with: URLRequest(url: URL(string: "https://example.com")!),
        from: Data()
    )
    private(set) var receivedURL: URL?
    private(set) var receivedRequest: URLRequest?
    private(set) var receivedData: Data?

    @objc dynamic func makeDownloadTask(
        _ url: URL,
        completionHandler: SentryDownloadTaskCompletionHandler?
    ) -> URLSessionDownloadTask {
        receivedURL = url
        completionHandler?(url, nil, nil)
        return downloadTask
    }

    @objc dynamic func makeUploadTask(
        _ request: URLRequest,
        data: Data?,
        completionHandler: SentryDataTaskCompletionHandler?
    ) -> URLSessionUploadTask {
        receivedRequest = request
        receivedData = data
        completionHandler?(data, nil, nil)
        return uploadTask
    }
}

private final class TypedSwizzleTaskStateTarget: NSObject {
    private(set) var receivedState: URLSessionTask.State?

    @objc dynamic func setState(_ state: URLSessionTask.State) {
        receivedState = state
    }
}

private class TypedSwizzleStateMismatchBase: NSObject {
    private(set) var receivedState: URLSessionTask.State?

    @objc dynamic func setState(_ state: URLSessionTask.State) {
        receivedState = state
    }
}

private final class TypedSwizzleStateMismatchChild: TypedSwizzleStateMismatchBase {}

private final class TypedSwizzleDataTaskTarget: NSObject {
    let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
    private(set) var receivedRequest: URLRequest?
    private(set) var receivedURL: URL?

    @objc dynamic func makeTaskWithRequest(
        _ request: URLRequest,
        completionHandler: SentryDataTaskCompletionHandler?
    ) -> URLSessionDataTask {
        receivedRequest = request
        completionHandler?(Data("original".utf8), nil, nil)
        return task
    }

    @objc dynamic func makeTaskWithURL(
        _ url: URL,
        completionHandler: SentryDataTaskCompletionHandler?
    ) -> URLSessionDataTask {
        receivedURL = url
        completionHandler?(Data("original".utf8), nil, nil)
        return task
    }
}

private class TypedSwizzleDataTaskMismatchBase: NSObject {
    let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
    private(set) var receivedRequest: URLRequest?
    private(set) var receivedURL: URL?

    @objc dynamic func makeTaskWithRequest(
        _ request: URLRequest,
        completionHandler: SentryDataTaskCompletionHandler?
    ) -> URLSessionDataTask {
        receivedRequest = request
        return task
    }

    @objc dynamic func makeTaskWithURL(
        _ url: URL,
        completionHandler: SentryDataTaskCompletionHandler?
    ) -> URLSessionDataTask {
        receivedURL = url
        return task
    }
}

private final class TypedSwizzleDataTaskMismatchChild: TypedSwizzleDataTaskMismatchBase {}

private final class TypedSwizzleURLSessionValidationTarget: NSObject {}
