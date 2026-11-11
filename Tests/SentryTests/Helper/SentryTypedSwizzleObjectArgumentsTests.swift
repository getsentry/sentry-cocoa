#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import ObjectiveC
import XCTest

final class SentryTypedSwizzleObjectArgumentsTests: XCTestCase {
    private var installations: [(selector: Selector, key: SentryTypedSwizzle.Key)] = []

    override func tearDown() {
        for installation in installations.reversed() {
            for target in [ObjectArgumentsSwizzleChild.self, ObjectArgumentsSwizzleTarget.self] {
                SentrySwizzle.unswizzleInstanceMethod(installation.selector, in: target, key: installation.key.pointer)
            }
        }
        installations.removeAll()
        super.tearDown()
    }

    // MARK: - Forwarding

    func testOneArgument_whenIntercepted_shouldForwardArgumentAndResult() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        let first = NSObject()
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method1, mode: .always, key: key(method1.selector)) { receiver, original in
            calls += 1
            XCTAssertTrue(receiver === target)
            return original()
        }

        // -- Act --
        let result = target.one(first)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.received.count, 1)
        XCTAssertTrue(target.received[0] === first)
        XCTAssertTrue(result === target.result)
    }

    func testTwoArguments_whenIntercepted_shouldForwardArgumentsAndResult() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        let arguments = [NSObject(), NSObject()]
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method2, mode: .always, key: key(method2.selector)) { _, original in
            calls += 1
            return original()
        }

        // -- Act --
        let result = target.two(arguments[0], arguments[1])

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(zip(target.received, arguments).allSatisfy { $0 === $1 })
        XCTAssertTrue(result === target.result)
    }

    func testThreeArguments_whenIntercepted_shouldForwardArgumentsAndResult() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        let arguments = [NSObject(), NSObject(), NSObject()]
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method3, mode: .always, key: key(method3.selector)) { _, original in
            calls += 1
            return original()
        }

        // -- Act --
        let result = target.three(arguments[0], arguments[1], arguments[2])

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.received.count, 3)
        XCTAssertTrue(zip(target.received, arguments).allSatisfy { $0 === $1 })
        XCTAssertTrue(result === target.result)
    }

    func testFourArguments_whenIntercepted_shouldForwardArgumentsAndResult() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        let arguments = [NSObject(), NSObject(), NSObject(), NSObject()]
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method4, mode: .always, key: key(method4.selector)) { _, original in
            calls += 1
            return original()
        }

        // -- Act --
        let result = target.four(arguments[0], arguments[1], arguments[2], arguments[3])

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.received.count, 4)
        XCTAssertTrue(zip(target.received, arguments).allSatisfy { $0 === $1 })
        XCTAssertTrue(result === target.result)
    }

    func testArguments_whenNil_shouldForwardNilArgumentsAndResult() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        target.result = nil
        XCTAssertTrue(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method4, mode: .always, key: key(method4.selector)) { _, original in
            original()
        })

        // -- Act --
        let result = target.four(nil, nil, nil, nil)

        // -- Assert --
        XCTAssertNil(result)
        XCTAssertEqual(target.received.count, 4)
        XCTAssertTrue(target.received.allSatisfy { $0 == nil })
    }

    func testResult_whenInterceptorReplacesIt_shouldReturnReplacement() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        let replacement = NSObject()
        XCTAssertTrue(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method1, mode: .always, key: key(method1.selector)) { _, original in
            _ = original()
            return replacement
        })

        // -- Act --
        let result = target.one(nil)

        // -- Assert --
        XCTAssertTrue(result === replacement)
        XCTAssertEqual(target.calls, 1)
    }

    // MARK: - Installation

    func testInstall_whenMethodIsInherited_shouldCallSuperclassOriginal() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleChild()
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleChild.self, method: method2, mode: .always, key: key(method2.selector)) { _, original in
            calls += 1
            return original()
        }

        // -- Act --
        let result = target.two(nil, nil)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.calls, 1)
        XCTAssertTrue(result === target.result)
    }

    func testInstall_whenInstalledTwiceWithSameKey_shouldCallInterceptorOnce() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        let stableKey = key(method1.selector)
        var calls = 0
        let intercept: (ObjectArgumentsSwizzleTarget, @escaping () -> AnyObject?) -> AnyObject? = { _, original in
            calls += 1
            return original()
        }

        // -- Act --
        let first = SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method1, mode: .oncePerClassAndSuperclasses, key: stableKey, interceptor: intercept)
        let second = SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method1, mode: .oncePerClassAndSuperclasses, key: stableKey, interceptor: intercept)
        _ = target.one(nil)

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.calls, 1)
    }

    func testInstall_whenUsingDifferentKeys_shouldChainOriginalImplementations() {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        var order: [String] = []
        XCTAssertTrue(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method3, mode: .oncePerClassAndSuperclasses, key: key(method3.selector)) { _, original in
            order.append("first")
            return original()
        })
        XCTAssertTrue(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: method3, mode: .oncePerClassAndSuperclasses, key: key(method3.selector)) { _, original in
            order.append("second")
            return original()
        })

        // -- Act --
        _ = target.three(nil, nil, nil)

        // -- Assert --
        XCTAssertEqual(order, ["second", "first"])
        XCTAssertEqual(target.calls, 1)
    }

    func testInstall_whenReceiverCastFails_shouldStillCallOriginal() throws {
        // -- Arrange --
        let target = ObjectArgumentsSwizzleTarget()
        var calls = 0
        let method = SentrySwizzleMethod<ObjectArgumentsSwizzleChild, SentrySwizzleObjectArguments1, AnyObject?>(
            selector: #selector(ObjectArgumentsSwizzleTarget.one(_:)), receiver: ObjectArgumentsSwizzleChild.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object])
        )
        XCTAssertTrue(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleChild.self, method: method, mode: .always, key: key(method.selector)) { _, original in
            calls += 1
            return original()
        })
        let imp = try XCTUnwrap(class_getMethodImplementation(ObjectArgumentsSwizzleChild.self, method.selector))
        let call = unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, AnyObject?) -> AnyObject?).self)

        // -- Act --
        let result = call(target, method.selector, nil)

        // -- Assert --
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(target.calls, 1)
        XCTAssertTrue(result === target.result)
    }

    func testInstall_whenValidationFails_shouldNotInstall() {
        // -- Arrange --
        let wrongReturn = SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments1, AnyObject?>(
            selector: method1.selector, receiver: ObjectArgumentsSwizzleTarget.self,
            signature: .init(returnType: .void, arguments: [.object, .selector, .object])
        )
        let wrongCount = SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments2, AnyObject?>(
            selector: method1.selector, receiver: ObjectArgumentsSwizzleTarget.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object])
        )
        let wrongType = SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments3, AnyObject?>(
            selector: method3.selector, receiver: ObjectArgumentsSwizzleTarget.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .selector, .object])
        )
        let missing = SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments4, AnyObject?>(
            selector: NSSelectorFromString("missing:b:c:d:"), receiver: ObjectArgumentsSwizzleTarget.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object, .object, .object])
        )
        let fail: (ObjectArgumentsSwizzleTarget, @escaping () -> AnyObject?) -> AnyObject? = { _, original in
            XCTFail("Invalid interceptor should not run")
            return original()
        }

        // -- Act & Assert --
        XCTAssertFalse(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: wrongReturn, mode: .always, key: key(wrongReturn.selector), interceptor: fail))
        XCTAssertFalse(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: wrongCount, mode: .always, key: key(wrongCount.selector), interceptor: fail))
        XCTAssertFalse(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: wrongType, mode: .always, key: key(wrongType.selector), interceptor: fail))
        XCTAssertFalse(SentryTypedSwizzle.instanceMethod(in: ObjectArgumentsSwizzleTarget.self, method: missing, mode: .always, key: key(missing.selector), interceptor: fail))
        _ = ObjectArgumentsSwizzleTarget().one(nil)
    }

    // MARK: - Helpers

    private var method1: SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments1, AnyObject?> {
        .init(selector: #selector(ObjectArgumentsSwizzleTarget.one(_:)), receiver: ObjectArgumentsSwizzleTarget.self,
              signature: .init(returnType: .object, arguments: [.object, .selector, .object]))
    }

    private var method2: SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments2, AnyObject?> {
        .init(selector: #selector(ObjectArgumentsSwizzleTarget.two(_:_:)), receiver: ObjectArgumentsSwizzleTarget.self,
              signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object]))
    }

    private var method3: SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments3, AnyObject?> {
        .init(selector: #selector(ObjectArgumentsSwizzleTarget.three(_:_:_:)), receiver: ObjectArgumentsSwizzleTarget.self,
              signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object, .object]))
    }

    private var method4: SentrySwizzleMethod<ObjectArgumentsSwizzleTarget, SentrySwizzleObjectArguments4, AnyObject?> {
        .init(selector: #selector(ObjectArgumentsSwizzleTarget.four(_:_:_:_:)), receiver: ObjectArgumentsSwizzleTarget.self,
              signature: .init(returnType: .object, arguments: [.object, .selector, .object, .object, .object, .object]))
    }

    private func key(_ selector: Selector) -> SentryTypedSwizzle.Key {
        let key = SentryTypedSwizzle.Key()
        installations.append((selector, key))
        return key
    }
}

private class ObjectArgumentsSwizzleTarget: NSObject {
    var result: AnyObject? = NSObject()
    var received: [AnyObject?] = []
    var calls = 0

    @objc dynamic func one(_ first: AnyObject?) -> AnyObject? {
        record([first])
    }

    @objc dynamic func two(_ first: AnyObject?, _ second: AnyObject?) -> AnyObject? {
        record([first, second])
    }

    @objc dynamic func three(_ first: AnyObject?, _ second: AnyObject?, _ third: AnyObject?) -> AnyObject? {
        record([first, second, third])
    }

    @objc dynamic func four(_ first: AnyObject?, _ second: AnyObject?, _ third: AnyObject?, _ fourth: AnyObject?) -> AnyObject? {
        record([first, second, third, fourth])
    }

    private func record(_ arguments: [AnyObject?]) -> AnyObject? {
        calls += 1
        received = arguments
        return result
    }
}

private final class ObjectArgumentsSwizzleChild: ObjectArgumentsSwizzleTarget {}
