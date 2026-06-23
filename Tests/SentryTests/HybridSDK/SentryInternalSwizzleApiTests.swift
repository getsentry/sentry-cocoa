@testable import Sentry
import XCTest

// swiftlint:disable function_body_length

private var swizzleKey1: UInt8 = 0
private var swizzleKey2: UInt8 = 0
private var swizzleKey3: UInt8 = 0
private var swizzleKey4: UInt8 = 0

class SentryInternalSwizzleApiTests: XCTestCase {

    private let sut = SentryInternalSwizzleApi()

    // MARK: - Mode

    func testMode_rawValues() {
        XCTAssertEqual(SentryInternalSwizzleApi.Mode.always.rawValue, 0)
        XCTAssertEqual(SentryInternalSwizzleApi.Mode.oncePerClass.rawValue, 1)
        XCTAssertEqual(SentryInternalSwizzleApi.Mode.oncePerClassAndSuperclasses.rawValue, 2)
    }

    // MARK: - instanceMethod

    func testInstanceMethod_shouldSwizzleAndCallReplacement() {
        // -- Arrange --
        var replacementCalled = false

        // -- Act --
        let result = sut.instanceMethod(
            #selector(SwizzleTarget.greet),
            in: SwizzleTarget.self,
            mode: .always,
            key: &swizzleKey1
        ) { getOriginal in
            { (target: SwizzleTarget) -> String in
                replacementCalled = true
                let original = unsafeBitCast(
                    getOriginal(),
                    to: (@convention(c) (SwizzleTarget, Selector) -> String).self
                )
                return original(target, #selector(SwizzleTarget.greet))
            } as @convention(block) (SwizzleTarget) -> String
        }
        let target = SwizzleTarget()
        let greeting = target.greet()

        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertTrue(replacementCalled)
        XCTAssertEqual(greeting, "hello")
    }

    func testInstanceMethod_shouldCallOriginalImplementation() {
        // -- Act --
        sut.instanceMethod(
            #selector(SwizzleTarget.computeValue),
            in: SwizzleTarget.self,
            mode: .always,
            key: &swizzleKey2
        ) { getOriginal in
            { (target: SwizzleTarget) -> Int in
                let original = unsafeBitCast(
                    getOriginal(),
                    to: (@convention(c) (SwizzleTarget, Selector) -> Int).self
                )
                return original(target, #selector(SwizzleTarget.computeValue)) + 100
            } as @convention(block) (SwizzleTarget) -> Int
        }
        let target = SwizzleTarget()
        let result = target.computeValue()

        // -- Assert --
        XCTAssertEqual(result, 142)
    }

    func testInstanceMethod_oncePerClass_shouldReturnFalseOnSecondSwizzle() {
        // -- Arrange --
        let factory: (@escaping () -> IMP) -> Any = { getOriginal in
            { (target: SwizzleOnceTarget) in
                let original = unsafeBitCast(
                    getOriginal(),
                    to: (@convention(c) (SwizzleOnceTarget, Selector) -> Void).self
                )
                original(target, #selector(SwizzleOnceTarget.doSomething))
            } as @convention(block) (SwizzleOnceTarget) -> Void
        }

        // -- Act --
        let firstResult = sut.instanceMethod(
            #selector(SwizzleOnceTarget.doSomething),
            in: SwizzleOnceTarget.self,
            mode: .oncePerClass,
            key: &swizzleKey3,
            factory: factory
        )
        let secondResult = sut.instanceMethod(
            #selector(SwizzleOnceTarget.doSomething),
            in: SwizzleOnceTarget.self,
            mode: .oncePerClass,
            key: &swizzleKey3,
            factory: factory
        )

        // -- Assert --
        XCTAssertTrue(firstResult)
        XCTAssertFalse(secondResult)
    }

    func testInstanceMethod_always_shouldReturnTrueOnSecondSwizzle() {
        // -- Arrange --
        let factory: (@escaping () -> IMP) -> Any = { getOriginal in
            { (target: SwizzleAlwaysTarget) in
                let original = unsafeBitCast(
                    getOriginal(),
                    to: (@convention(c) (SwizzleAlwaysTarget, Selector) -> Void).self
                )
                original(target, #selector(SwizzleAlwaysTarget.doSomething))
            } as @convention(block) (SwizzleAlwaysTarget) -> Void
        }

        // -- Act --
        let firstResult = sut.instanceMethod(
            #selector(SwizzleAlwaysTarget.doSomething),
            in: SwizzleAlwaysTarget.self,
            mode: .always,
            key: &swizzleKey4,
            factory: factory
        )
        let secondResult = sut.instanceMethod(
            #selector(SwizzleAlwaysTarget.doSomething),
            in: SwizzleAlwaysTarget.self,
            mode: .always,
            key: &swizzleKey4,
            factory: factory
        )

        // -- Assert --
        XCTAssertTrue(firstResult)
        XCTAssertTrue(secondResult)
    }
}

// swiftlint:enable function_body_length

// MARK: - Test helpers

private class SwizzleTarget: NSObject {
    @objc dynamic func greet() -> String { "hello" }
    @objc dynamic func computeValue() -> Int { 42 }
}

private class SwizzleOnceTarget: NSObject {
    @objc dynamic func doSomething() {}
}

private class SwizzleAlwaysTarget: NSObject {
    @objc dynamic func doSomething() {}
}
