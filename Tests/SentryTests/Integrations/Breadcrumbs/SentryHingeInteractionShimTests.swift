@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS)

/// Stands in for `UIHingeInteraction` in the runtime shim tests, with the same initializer selector.
@objc(SentryTestRuntimeHingeInteraction)
final class SentryTestRuntimeHingeInteraction: NSObject, UIInteraction {
    weak var view: UIView?
    let updateHandler: (AnyObject, AnyObject) -> Void

    @objc init(updateHandler: @escaping (AnyObject, AnyObject) -> Void) {
        self.updateHandler = updateHandler
    }

    func willMove(to view: UIView?) {}

    func didMove(to view: UIView?) {
        self.view = view
    }
}

class SentryHingeInteractionShimTests: XCTestCase {

    @objc private final class FakeHinge: NSObject {
        @objc let status: Int
        @objc let angle: Double

        init(status: Int, angle: Double) {
            self.status = status
            self.angle = angle
        }
    }

    @objc private final class FakeUpdate: NSObject {
        @objc let hinge: FakeHinge?

        init(hinge: FakeHinge?) {
            self.hinge = hinge
        }
    }

    private final class UpdateWithoutHinge: NSObject {}

    private func getRuntimeSut() -> SentryRuntimeHingeInteractionShim {
        SentryRuntimeHingeInteractionShim(className: NSStringFromClass(SentryTestRuntimeHingeInteraction.self))
    }

    // MARK: - Shim Selection

    func testMake_shouldMatchRuntimeAvailability() {
        // -- Act --
        let sut = SentryHingeInteractionShims.make()

        // -- Assert --
        XCTAssertEqual(sut.isAvailable, NSClassFromString("UIHingeInteraction") != nil)
    }

    // MARK: - Runtime Shim

    func testRuntimeIsAvailable_whenClassMissing_shouldBeFalse() {
        // -- Arrange --
        let sut = SentryRuntimeHingeInteractionShim(className: "SentryMissingHingeInteraction")

        // -- Act & Assert --
        XCTAssertFalse(sut.isAvailable)
        XCTAssertNil(sut.makeInteraction { _ in })
    }

    func testRuntimeIsAvailable_whenClassLacksInitializer_shouldBeFalse() {
        // -- Arrange --
        let sut = SentryRuntimeHingeInteractionShim(className: NSStringFromClass(NSObject.self))

        // -- Act & Assert --
        XCTAssertFalse(sut.isAvailable)
        XCTAssertNil(sut.makeInteraction { _ in })
    }

    func testRuntimeMakeInteraction_shouldCreateInteractionForwardingUpdates() throws {
        // -- Arrange --
        let sut = getRuntimeSut()
        var states: [SentryHingeState?] = []

        // -- Act --
        let interaction = try XCTUnwrap(sut.makeInteraction { states.append($0) } as? SentryTestRuntimeHingeInteraction)
        interaction.updateHandler(interaction, FakeUpdate(hinge: FakeHinge(status: 3, angle: 3.0)))
        interaction.updateHandler(interaction, FakeUpdate(hinge: nil))

        // -- Assert --
        XCTAssertTrue(sut.isAvailable)
        XCTAssertEqual(states, [SentryHingeState(status: .fullyOpen, angle: 3.0), nil])
    }

    func testRuntimeMakeInteraction_shouldNotRetainUpdateHandlerTarget() throws {
        // -- Arrange --
        let sut = getRuntimeSut()
        var interaction: UIInteraction?
        weak var weakTarget: NSObject?

        // -- Act --
        autoreleasepool {
            let target = NSObject()
            weakTarget = target
            interaction = sut.makeInteraction { [weak target] _ in _ = target }
        }

        // -- Assert --
        XCTAssertNotNil(interaction)
        XCTAssertNil(weakTarget)
    }

    func testRuntimeMakeInteraction_whenRuntimeProvidesHinge_shouldCreateHingeInteraction() throws {
        // Runs without the iOS 27.1 SDK too, so the selector path is checked against the real class.
        try XCTSkipIf(NSClassFromString("UIHingeInteraction") == nil, "UIHingeInteraction requires iOS 27.1")

        // -- Arrange --
        let sut = SentryRuntimeHingeInteractionShim()

        // -- Act --
        let interaction = try XCTUnwrap(sut.makeInteraction { _ in })

        // -- Assert --
        XCTAssertTrue(sut.isAvailable)
        XCTAssertEqual(NSStringFromClass(type(of: interaction)), "UIHingeInteraction")
    }

    func testHingeState_whenUpdateHasHinge_shouldReturnState() throws {
        // -- Arrange --
        let update = FakeUpdate(hinge: FakeHinge(status: 2, angle: 1.25))

        // -- Act --
        let state = try XCTUnwrap(SentryRuntimeHingeInteractionShim.hingeState(from: update))

        // -- Assert --
        XCTAssertEqual(state.status, .partiallyOpen)
        XCTAssertEqual(state.angle, 1.25)
    }

    func testHingeState_whenStatusIsUnrecognized_shouldReturnUnknown() throws {
        // -- Arrange --
        let update = FakeUpdate(hinge: FakeHinge(status: 42, angle: 0))

        // -- Act --
        let state = try XCTUnwrap(SentryRuntimeHingeInteractionShim.hingeState(from: update))

        // -- Assert --
        XCTAssertEqual(state.status, .unknown)
    }

    func testHingeState_whenHingeIsNil_shouldReturnNil() {
        XCTAssertNil(SentryRuntimeHingeInteractionShim.hingeState(from: FakeUpdate(hinge: nil)))
    }

    func testHingeState_whenUpdateDoesNotRespondToHinge_shouldReturnNil() {
        XCTAssertNil(SentryRuntimeHingeInteractionShim.hingeState(from: UpdateWithoutHinge()))
    }

    // MARK: - Native Shim

    // Same gate as SentryHingeInteractionShim: the iOS 27.1 SDK is the first one shipping UIHingeInteraction.
    #if canImport(SwiftUI, _version: 8.0.85)

    func testMake_whenCompiledWithHingeSDK_shouldUseNativeShimOnSupportedRuntime() throws {
        guard #available(iOS 27.1, *) else {
            throw XCTSkip("UIHingeInteraction requires iOS 27.1")
        }

        XCTAssertTrue(SentryHingeInteractionShims.make() is SentryNativeHingeInteractionShim)
    }

    func testNativeMakeInteraction_shouldCreateHingeInteraction() throws {
        guard #available(iOS 27.1, *) else {
            throw XCTSkip("UIHingeInteraction requires iOS 27.1")
        }

        XCTAssertTrue(SentryNativeHingeInteractionShim().makeInteraction { _ in } is UIHingeInteraction)
    }

    func testHingeStatus_whenInitializedFromUIHingeStatus_shouldMapEveryCase() throws {
        guard #available(iOS 27.1, *) else {
            throw XCTSkip("UIHinge.Status requires iOS 27.1")
        }

        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.unknown), .unknown)
        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.closed), .closed)
        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.partiallyOpen), .partiallyOpen)
        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.fullyOpen), .fullyOpen)
    }

    #endif // canImport(SwiftUI, _version: 8.0.85)
}
#endif // os(iOS)
