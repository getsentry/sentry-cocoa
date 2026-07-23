@testable import Sentry
import Foundation
import XCTest

final class SentryTypedSwizzleTests: XCTestCase {

    func testValidate_whenNoArgumentVoidMethodMatches_shouldReturnTrue() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(TypedSwizzleTestTarget.self)

        // -- Act --
        let result = SentryTypedSwizzle.validate(
            #selector(TypedSwizzleTestTarget.noArguments),
            in: TypedSwizzleTestTarget.self,
            method: method
        )

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testValidate_whenSelectorIsMissing_shouldReturnFalse() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(TypedSwizzleTestTarget.self)

        // -- Act --
        let result = SentryTypedSwizzle.validate(
            NSSelectorFromString("missingMethod"),
            in: TypedSwizzleTestTarget.self,
            method: method
        )

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenArgumentCountDoesNotMatch_shouldReturnFalse() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(TypedSwizzleTestTarget.self)

        // -- Act --
        let result = SentryTypedSwizzle.validate(
            #selector(TypedSwizzleTestTarget.objectArgument(_:)),
            in: TypedSwizzleTestTarget.self,
            method: method
        )

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenReturnTypeDoesNotMatch_shouldReturnFalse() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(TypedSwizzleTestTarget.self)

        // -- Act --
        let result = SentryTypedSwizzle.validate(
            #selector(TypedSwizzleTestTarget.returnsObject),
            in: TypedSwizzleTestTarget.self,
            method: method
        )

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenTaskStateScalarDoesNotMatch_shouldReturnFalse() {
        // -- Act --
        let result = SentryTypedSwizzle.validate(
            #selector(TypedSwizzleTestTarget.boolArgument(_:)),
            in: TypedSwizzleTestTarget.self,
            method: .urlSessionTaskState(TypedSwizzleTestTarget.self)
        )

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenRequestCompletionBlockPositionDoesNotMatch_shouldReturnFalse() {
        // -- Act --
        let result = SentryTypedSwizzle.validate(
            #selector(TypedSwizzleTestTarget.twoObjectArguments(_:second:)),
            in: TypedSwizzleTestTarget.self,
            method: .urlSessionDataTaskWithRequest(TypedSwizzleTestTarget.self)
        )

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenReceiverTypeDoesNotMatchClass_shouldReturnFalse() {
        // -- Act --
        let result = SentryTypedSwizzle.validate(
            #selector(TypedSwizzleNoArgumentTarget.invoke),
            in: TypedSwizzleNoArgumentTarget.self,
            method: .noArgumentVoid(TypedSwizzleTestTarget.self)
        )

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidationFailure_whenReturnTypeDoesNotMatch_shouldDescribeExpectedAndActualSignatures() throws {
        // -- Act --
        let failure = SentryTypedSwizzle.validationFailure(
            #selector(TypedSwizzleTestTarget.returnsObject),
            in: TypedSwizzleTestTarget.self,
            method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void>.noArgumentVoid(TypedSwizzleTestTarget.self)
        )

        // -- Assert --
        let unwrappedFailure = try XCTUnwrap(failure)
        XCTAssertTrue(unwrappedFailure.contains("expected v@:"))
        XCTAssertTrue(unwrappedFailure.contains("actual @@:"))
    }

    func testInstanceMethod_whenNoArgumentVoidMethod_shouldCallInterceptorAndOriginal() {
        // -- Arrange --
        let key = SentrySwizzleKey()
        let target = TypedSwizzleNoArgumentTarget()
        var interceptedTarget: TypedSwizzleNoArgumentTarget?

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleNoArgumentTarget.invoke),
            in: TypedSwizzleNoArgumentTarget.self,
            method: .noArgumentVoid(TypedSwizzleNoArgumentTarget.self),
            mode: .always,
            key: key
        ) { receiver, original in
            interceptedTarget = receiver
            original()
        }
        target.invoke()

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertIdentical(interceptedTarget, target)
        XCTAssertEqual(target.originalCallCount, 1)
    }

    func testInstanceMethod_whenOriginalIsInherited_shouldCallSuperclassImplementation() {
        // -- Arrange --
        let key = SentrySwizzleKey()
        let target = TypedSwizzleInheritedTarget()

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleInheritedBase.invoke),
            in: TypedSwizzleInheritedTarget.self,
            method: .noArgumentVoid(TypedSwizzleInheritedTarget.self),
            mode: .always,
            key: key
        ) { _, original in
            original()
        }
        target.invoke()

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(target.originalCallCount, 1)
    }

    func testInstanceMethod_whenTaskStateMethod_shouldReplaceArgument() {
        // -- Arrange --
        let key = SentrySwizzleKey()
        let target = TypedSwizzleTaskStateTarget()

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleTaskStateTarget.setState(_:)),
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

    func testInstanceMethod_whenRequestDataTaskMethod_shouldWrapCompletionAndReturnOriginalResult() throws {
        // -- Arrange --
        let key = SentrySwizzleKey()
        let target = TypedSwizzleDataTaskTarget()
        let request = URLRequest(url: URL(string: "https://example.com/original")!)
        let replacementRequest = URLRequest(url: URL(string: "https://example.com/replacement")!)
        var completionData: Data?

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleDataTaskTarget.makeTaskWithRequest(_:completionHandler:)),
            in: TypedSwizzleDataTaskTarget.self,
            method: .urlSessionDataTaskWithRequest(TypedSwizzleDataTaskTarget.self),
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
        let key = SentrySwizzleKey()
        let target = TypedSwizzleDataTaskTarget()
        let url = URL(string: "https://example.com/original")!
        let replacementURL = URL(string: "https://example.com/replacement")!

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleDataTaskTarget.makeTaskWithURL(_:completionHandler:)),
            in: TypedSwizzleDataTaskTarget.self,
            method: .urlSessionDataTaskWithURL(TypedSwizzleDataTaskTarget.self),
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

    func testInstanceMethod_whenDifferentKeysAreUsed_shouldAllowBothInstallations() {
        // -- Arrange --
        let firstKey = SentrySwizzleKey()
        let secondKey = SentrySwizzleKey()
        let method = SentrySwizzleMethod<TypedSwizzleDistinctKeyTarget, Void, Void>.noArgumentVoid(TypedSwizzleDistinctKeyTarget.self)
        let interceptor: (TypedSwizzleDistinctKeyTarget, @escaping () -> Void) -> Void = { _, original in
            original()
        }

        // -- Act --
        let first = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleDistinctKeyTarget.invoke),
            in: TypedSwizzleDistinctKeyTarget.self,
            method: method,
            mode: .oncePerClass,
            key: firstKey,
            interceptor: interceptor
        )
        let second = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleDistinctKeyTarget.invoke),
            in: TypedSwizzleDistinctKeyTarget.self,
            method: method,
            mode: .oncePerClass,
            key: secondKey,
            interceptor: interceptor
        )

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertTrue(second)
    }

    func testInstanceMethod_whenOncePerClassIsRepeated_shouldRejectSecondInstallation() {
        // -- Arrange --
        let key = SentrySwizzleKey()
        let method = SentrySwizzleMethod<TypedSwizzleOnceTarget, Void, Void>.noArgumentVoid(TypedSwizzleOnceTarget.self)
        let interceptor: (TypedSwizzleOnceTarget, @escaping () -> Void) -> Void = { _, original in
            original()
        }

        // -- Act --
        let first = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleOnceTarget.invoke),
            in: TypedSwizzleOnceTarget.self,
            method: method,
            mode: .oncePerClass,
            key: key,
            interceptor: interceptor
        )
        let second = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleOnceTarget.invoke),
            in: TypedSwizzleOnceTarget.self,
            method: method,
            mode: .oncePerClass,
            key: key,
            interceptor: interceptor
        )

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertFalse(second)
    }

    func testInstanceMethod_whenSuperclassWasSwizzled_shouldRejectSubclassInstallation() {
        // -- Arrange --
        let key = SentrySwizzleKey()

        // -- Act --
        let superclassInstalled = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleModeBase.invoke),
            in: TypedSwizzleModeBase.self,
            method: .noArgumentVoid(TypedSwizzleModeBase.self),
            mode: .oncePerClassAndSuperclasses,
            key: key
        ) { _, original in
            original()
        }
        let subclassInstalled = SentryTypedSwizzle.instanceMethod(
            #selector(TypedSwizzleModeBase.invoke),
            in: TypedSwizzleModeTarget.self,
            method: .noArgumentVoid(TypedSwizzleModeTarget.self),
            mode: .oncePerClassAndSuperclasses,
            key: key
        ) { _, original in
            original()
        }

        // -- Assert --
        XCTAssertTrue(superclassInstalled)
        XCTAssertFalse(subclassInstalled)
    }
}

private final class TypedSwizzleTestTarget: NSObject {
    @objc dynamic func noArguments() {}
    @objc dynamic func objectArgument(_ value: NSObject) {}
    @objc dynamic func boolArgument(_ value: Bool) {}
    @objc dynamic func returnsObject() -> NSObject { NSObject() }
    @objc dynamic func twoObjectArguments(_ first: NSObject, second: NSObject) -> NSObject { NSObject() }
}

private final class TypedSwizzleNoArgumentTarget: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private class TypedSwizzleInheritedBase: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private final class TypedSwizzleInheritedTarget: TypedSwizzleInheritedBase {}

private final class TypedSwizzleTaskStateTarget: NSObject {
    private(set) var receivedState: URLSessionTask.State?

    @objc dynamic func setState(_ state: URLSessionTask.State) {
        receivedState = state
    }
}

private final class TypedSwizzleDistinctKeyTarget: NSObject {
    @objc dynamic func invoke() {}
}

private final class TypedSwizzleOnceTarget: NSObject {
    @objc dynamic func invoke() {}
}

private class TypedSwizzleModeBase: NSObject {
    @objc dynamic func invoke() {}
}

private final class TypedSwizzleModeTarget: TypedSwizzleModeBase {}

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
