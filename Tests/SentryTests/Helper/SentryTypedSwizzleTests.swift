@testable import Sentry
import Foundation
import ObjectiveC
import SentryTestUtils
import XCTest

final class SentryTypedSwizzleTests: XCTestCase {

    func testKey_whenCopied_shouldPreserveIdentity() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()

        // -- Act --
        let copy = key

        // -- Assert --
        XCTAssertEqual(key.pointer, copy.pointer)
    }

    func testKey_whenInitializedSeparately_shouldHaveDistinctIdentity() {
        // -- Arrange --
        let first = SentryTypedSwizzle.Key()
        let second = SentryTypedSwizzle.Key()

        // -- Assert --
        XCTAssertNotEqual(first.pointer, second.pointer)
    }

    func testValidate_whenNoArgumentVoidMethodMatches_shouldReturnTrue() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(
            #selector(TypedSwizzleTestTarget.noArguments),
            receiver: TypedSwizzleTestTarget.self
        )

        // -- Act --
        let result = SentryTypedSwizzle.validate(in: TypedSwizzleTestTarget.self, method: method)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testValidate_whenSelectorIsMissing_shouldReturnFalse() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(
            NSSelectorFromString("missingMethod"),
            receiver: TypedSwizzleTestTarget.self
        )

        // -- Act --
        let result = SentryTypedSwizzle.validate(in: TypedSwizzleTestTarget.self, method: method)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenArgumentCountDoesNotMatch_shouldReturnFalse() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(
            #selector(TypedSwizzleTestTarget.objectArgument(_:)),
            receiver: TypedSwizzleTestTarget.self
        )

        // -- Act --
        let result = SentryTypedSwizzle.validate(in: TypedSwizzleTestTarget.self, method: method)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenReturnTypeDoesNotMatch_shouldReturnFalse() {
        // -- Arrange --
        let method: SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void> = .noArgumentVoid(
            #selector(TypedSwizzleTestTarget.returnsObject),
            receiver: TypedSwizzleTestTarget.self
        )

        // -- Act --
        let result = SentryTypedSwizzle.validate(in: TypedSwizzleTestTarget.self, method: method)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenTaskStateScalarDoesNotMatch_shouldReturnFalse() {
        // -- Arrange --
        let method = SentrySwizzleMethod<TypedSwizzleTestTarget, URLSessionTask.State, Void>(
            selector: #selector(TypedSwizzleTestTarget.boolArgument(_:)),
            receiver: TypedSwizzleTestTarget.self,
            signature: .init(
                returnType: .void,
                arguments: [.object, .selector, .signedInteger(MemoryLayout<Int>.size)]
            )
        )

        // -- Act --
        let result = SentryTypedSwizzle.validate(in: TypedSwizzleTestTarget.self, method: method)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenRequestCompletionBlockPositionDoesNotMatch_shouldReturnFalse() {
        // -- Arrange --
        let method = SentrySwizzleMethod<TypedSwizzleTestTarget, SentryDataTaskRequestArguments, URLSessionDataTask>(
            selector: #selector(TypedSwizzleTestTarget.twoObjectArguments(_:second:)),
            receiver: TypedSwizzleTestTarget.self,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )

        // -- Act --
        let result = SentryTypedSwizzle.validate(in: TypedSwizzleTestTarget.self, method: method)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidate_whenReceiverTypeDoesNotMatchClass_shouldReturnFalse() {
        // -- Arrange --
        let method = SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void>.noArgumentVoid(
            #selector(TypedSwizzleNoArgumentTarget.invoke),
            receiver: TypedSwizzleTestTarget.self
        )

        // -- Act --
        let result = SentryTypedSwizzle.validate(in: TypedSwizzleNoArgumentTarget.self, method: method)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testValidationFailure_whenReturnTypeDoesNotMatch_shouldDescribeExpectedAndActualSignatures() throws {
        // -- Arrange --
        let method = SentrySwizzleMethod<TypedSwizzleTestTarget, Void, Void>.noArgumentVoid(
            #selector(TypedSwizzleTestTarget.returnsObject),
            receiver: TypedSwizzleTestTarget.self
        )

        // -- Act --
        let failure = SentryTypedSwizzle.validationFailure(in: TypedSwizzleTestTarget.self, method: method)

        // -- Assert --
        let unwrappedFailure = try XCTUnwrap(failure)
        XCTAssertTrue(unwrappedFailure.contains("expected v@:"))
        XCTAssertTrue(unwrappedFailure.contains("actual @@:"))
    }

    func testInstanceMethod_whenNoArgumentVoidMethod_shouldCallInterceptorAndOriginal() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleNoArgumentTarget()
        var interceptedTarget: TypedSwizzleNoArgumentTarget?

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleNoArgumentTarget.self,
            method: .noArgumentVoid(#selector(TypedSwizzleNoArgumentTarget.invoke), receiver: TypedSwizzleNoArgumentTarget.self),
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
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleInheritedTarget()

        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleInheritedTarget.self,
            method: .noArgumentVoid(#selector(TypedSwizzleInheritedBase.invoke), receiver: TypedSwizzleInheritedTarget.self),
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

    func testInstanceMethod_whenAlwaysIsRepeated_shouldChainInterceptorsAndCallOriginalOnce() {
        // -- Arrange --
        let target = TypedSwizzleAlwaysTarget()
        let method = SentrySwizzleMethod<TypedSwizzleAlwaysTarget, Void, Void>.noArgumentVoid(
            #selector(TypedSwizzleAlwaysTarget.invoke),
            receiver: TypedSwizzleAlwaysTarget.self
        )
        let calls = Invocations<String>()

        // -- Act --
        let first = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleAlwaysTarget.self,
            method: method,
            mode: .always,
            key: SentryTypedSwizzle.Key()
        ) { _, original in
            calls.record("first-before")
            original()
            calls.record("first-after")
        }
        let second = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleAlwaysTarget.self,
            method: method,
            mode: .always,
            key: SentryTypedSwizzle.Key()
        ) { _, original in
            calls.record("second-before")
            original()
            calls.record("second-after")
        }
        let third = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleAlwaysTarget.self,
            method: method,
            mode: .always,
            key: SentryTypedSwizzle.Key()
        ) { _, original in
            calls.record("third-before")
            original()
            calls.record("third-after")
        }
        target.invoke()

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertTrue(third)
        XCTAssertEqual(
            calls.invocations,
            ["third-before", "second-before", "first-before", "first-after", "second-after", "third-after"]
        )
        XCTAssertEqual(target.originalCallCount, 1)
    }

    func testInstanceMethod_whenDifferentKeysAreUsed_shouldChainInterceptorsAndCallOriginalOnce() {
        // -- Arrange --
        let firstKey = SentryTypedSwizzle.Key()
        let secondKey = SentryTypedSwizzle.Key()
        let target = TypedSwizzleDistinctKeyTarget()
        let method = SentrySwizzleMethod<TypedSwizzleDistinctKeyTarget, Void, Void>.noArgumentVoid(
            #selector(TypedSwizzleDistinctKeyTarget.invoke),
            receiver: TypedSwizzleDistinctKeyTarget.self
        )
        let calls = Invocations<String>()

        // -- Act --
        let first = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleDistinctKeyTarget.self,
            method: method,
            mode: .oncePerClass,
            key: firstKey
        ) { _, original in
            calls.record("first")
            original()
        }
        let second = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleDistinctKeyTarget.self,
            method: method,
            mode: .oncePerClass,
            key: secondKey
        ) { _, original in
            calls.record("second")
            original()
        }
        target.invoke()

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(calls.invocations, ["second", "first"])
        XCTAssertEqual(target.originalCallCount, 1)
    }

    func testInstanceMethod_whenOncePerClassIsRepeated_shouldRejectSecondInstallation() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let method = SentrySwizzleMethod<TypedSwizzleOnceTarget, Void, Void>.noArgumentVoid(#selector(TypedSwizzleOnceTarget.invoke), receiver: TypedSwizzleOnceTarget.self)
        let interceptor: (TypedSwizzleOnceTarget, @escaping () -> Void) -> Void = { _, original in
            original()
        }

        // -- Act --
        let first = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleOnceTarget.self,
            method: method,
            mode: .oncePerClass,
            key: key,
            interceptor: interceptor
        )
        let second = SentryTypedSwizzle.instanceMethod(
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

    func testInstanceMethod_whenOncePerClassUsesSuperclassAndSubclass_shouldInstallAndChainBoth() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleOncePerClassTarget()
        let calls = Invocations<String>()

        // -- Act --
        let superclassInstalled = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleOncePerClassBase.self,
            method: .noArgumentVoid(
                #selector(TypedSwizzleOncePerClassBase.invoke),
                receiver: TypedSwizzleOncePerClassBase.self
            ),
            mode: .oncePerClass,
            key: key
        ) { _, original in
            calls.record("superclass")
            original()
        }
        let subclassInstalled = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleOncePerClassTarget.self,
            method: .noArgumentVoid(
                #selector(TypedSwizzleOncePerClassBase.invoke),
                receiver: TypedSwizzleOncePerClassTarget.self
            ),
            mode: .oncePerClass,
            key: key
        ) { _, original in
            calls.record("subclass")
            original()
        }
        target.invoke()

        // -- Assert --
        XCTAssertTrue(superclassInstalled)
        XCTAssertTrue(subclassInstalled)
        XCTAssertEqual(calls.invocations, ["subclass", "superclass"])
        XCTAssertEqual(target.originalCallCount, 1)
    }

    func testInstanceMethod_whenSuperclassWasSwizzled_shouldRejectSubclassInstallation() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()

        // -- Act --
        let superclassInstalled = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleModeBase.self,
            method: .noArgumentVoid(#selector(TypedSwizzleModeBase.invoke), receiver: TypedSwizzleModeBase.self),
            mode: .oncePerClassAndSuperclasses,
            key: key
        ) { _, original in
            original()
        }
        let subclassInstalled = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleModeTarget.self,
            method: .noArgumentVoid(#selector(TypedSwizzleModeBase.invoke), receiver: TypedSwizzleModeTarget.self),
            mode: .oncePerClassAndSuperclasses,
            key: key
        ) { _, original in
            original()
        }

        // -- Assert --
        XCTAssertTrue(superclassInstalled)
        XCTAssertFalse(subclassInstalled)
    }

    func testInstanceMethod_whenSubclassWasSwizzledFirst_shouldAllowSuperclassInstallation() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleSubclassFirstTarget()
        let calls = Invocations<String>()

        // -- Act --
        let subclassInstalled = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleSubclassFirstTarget.self,
            method: .noArgumentVoid(
                #selector(TypedSwizzleSubclassFirstBase.invoke),
                receiver: TypedSwizzleSubclassFirstTarget.self
            ),
            mode: .oncePerClassAndSuperclasses,
            key: key
        ) { _, original in
            calls.record("subclass")
            original()
        }
        let superclassInstalled = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleSubclassFirstBase.self,
            method: .noArgumentVoid(
                #selector(TypedSwizzleSubclassFirstBase.invoke),
                receiver: TypedSwizzleSubclassFirstBase.self
            ),
            mode: .oncePerClassAndSuperclasses,
            key: key
        ) { _, original in
            calls.record("superclass")
            original()
        }
        target.invoke()

        // -- Assert --
        XCTAssertTrue(subclassInstalled)
        XCTAssertTrue(superclassInstalled)
        XCTAssertEqual(calls.invocations, ["subclass", "superclass"])
        XCTAssertEqual(target.originalCallCount, 1)
    }

    func testInstanceMethod_whenVoidReceiverCastFails_shouldStillCallOriginal() throws {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let selector = #selector(TypedSwizzleReceiverMismatchBase.invoke)
        var interceptorCallCount = 0
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleReceiverMismatchChild.self,
            method: .noArgumentVoid(selector, receiver: TypedSwizzleReceiverMismatchChild.self),
            mode: .always,
            key: key
        ) { _, original in
            interceptorCallCount += 1
            original()
        }
        XCTAssertTrue(installed)

        // Invoke the installed trampoline directly with a receiver whose type is the superclass,
        // forcing the `receiver as? Receiver` cast to the subclass to fail.
        let imp = try XCTUnwrap(class_getMethodImplementation(TypedSwizzleReceiverMismatchChild.self, selector))
        typealias VoidMethod = @convention(c) (AnyObject, Selector) -> Void
        let trampoline = unsafeBitCast(imp, to: VoidMethod.self)
        let mismatchedReceiver = TypedSwizzleReceiverMismatchBase()

        // -- Act --
        trampoline(mismatchedReceiver, selector)

        // -- Assert --
        XCTAssertEqual(interceptorCallCount, 0, "Interceptor must not run for a mismatched receiver")
        XCTAssertEqual(mismatchedReceiver.originalCallCount, 1, "Original must still be invoked when the receiver cast fails")
    }

    func testInstanceMethod_whenVoidValidationFails_shouldNotInstall() {
        // -- Act --
        let installed = SentryTypedSwizzle.instanceMethod(
            in: TypedSwizzleTestTarget.self,
            method: .noArgumentVoid(NSSelectorFromString("missingMethod"), receiver: TypedSwizzleTestTarget.self),
            mode: .always,
            key: SentryTypedSwizzle.Key()
        ) { _, original in
            original()
        }

        // -- Assert --
        XCTAssertFalse(installed)
    }

    func testInstanceMethod_whenInstalledConcurrentlyOncePerClass_shouldInstallExactlyOnce() {
        // -- Arrange --
        let key = SentryTypedSwizzle.Key()
        let target = TypedSwizzleConcurrentTarget()
        let method = SentrySwizzleMethod<TypedSwizzleConcurrentTarget, Void, Void>.noArgumentVoid(
            #selector(TypedSwizzleConcurrentTarget.invoke),
            receiver: TypedSwizzleConcurrentTarget.self
        )
        let results = SentryMutex<[Bool]>([])
        let interceptorCallCount = SentryMutex(0)

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            let installed = SentryTypedSwizzle.instanceMethod(
                in: TypedSwizzleConcurrentTarget.self,
                method: method,
                mode: .oncePerClass,
                key: key
            ) { _, original in
                interceptorCallCount.withLock { $0 += 1 }
                original()
            }
            results.withLock { $0.append(installed) }
        }
        target.invoke()

        // -- Assert --
        XCTAssertEqual(results.withLock { $0.filter { $0 }.count }, 1)
        XCTAssertEqual(results.withLock { $0.filter { !$0 }.count }, 19)
        XCTAssertEqual(interceptorCallCount.withLock { $0 }, 1)
        XCTAssertEqual(target.originalCallCount, 1)
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

private final class TypedSwizzleAlwaysTarget: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private final class TypedSwizzleDistinctKeyTarget: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private final class TypedSwizzleOnceTarget: NSObject {
    @objc dynamic func invoke() {}
}

private class TypedSwizzleOncePerClassBase: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private final class TypedSwizzleOncePerClassTarget: TypedSwizzleOncePerClassBase {}

private class TypedSwizzleModeBase: NSObject {
    @objc dynamic func invoke() {}
}

private final class TypedSwizzleModeTarget: TypedSwizzleModeBase {}

private class TypedSwizzleSubclassFirstBase: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private final class TypedSwizzleSubclassFirstTarget: TypedSwizzleSubclassFirstBase {}

private final class TypedSwizzleConcurrentTarget: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private class TypedSwizzleReceiverMismatchBase: NSObject {
    private(set) var originalCallCount = 0

    @objc dynamic func invoke() {
        originalCallCount += 1
    }
}

private final class TypedSwizzleReceiverMismatchChild: TypedSwizzleReceiverMismatchBase {}
