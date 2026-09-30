@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

/** Some of the test parameters are copied during debugging a working implementation. */
class SentryCrashStackEntryMapperTests: XCTestCase {

    private let bundleExecutable: String = "iOS-Swift"
    private var sut: SentryCrashStackEntryMapper!

    override func setUp() {
        super.setUp()
        sut = SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [bundleExecutable]))
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testInstructionAddress() {
        let frame = sut.mapAddress(2_412_813_376)

        XCTAssertEqual("0x000000008fd09c40", frame.instructionAddress ?? "")
    }

    func testImageFromCache() {
        let image = createBinaryImage(2_488_998_912)
        let cache = SentryDependencyContainer.sharedInstance().binaryImageCache
        cache.start(false)
        cache.binaryImageAdded(image)

        let frame = sut.mapAddress(2_488_998_950)

        XCTAssertEqual("0x00000000945b1c00", frame.imageAddress ?? "")
        XCTAssertEqual("Expected Name at 2488998912", frame.package)

        cache.stop()
    }

    private func createBinaryImage(_ address: UInt64) -> SentryBinaryImageInfo {
        SentryBinaryImageInfo(
            name: "Expected Name at \(address)",
            uuid: nil,
            vmAddress: 0,
            address: address,
            size: 100
        )
    }
}
