#if SDK_V10
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryKSCrashBinaryImageProviderTests: XCTestCase {
    private var sut: SentryBinaryImageCache!

    override func setUp() {
        super.setUp()
        sut = SentryBinaryImageCache(provider: SentryKSCrash.BinaryImageProvider())
    }

    override func tearDown() {
        sut.stop()
        sut = nil
        super.tearDown()
    }

    func testStart_shouldPublishKSCrashBinaryImages() throws {
        // -- Act --
        sut.start(false)

        // -- Assert --
        let images = try XCTUnwrap(sut.cache)
        XCTAssertFalse(images.isEmpty)
        XCTAssertTrue(images.allSatisfy { !$0.name.isEmpty })
        XCTAssertTrue(images.allSatisfy { $0.address > 0 })
    }

    func testStart_shouldIncludeDyld() throws {
        // -- Act --
        sut.start(false)

        // -- Assert --
        let images = try XCTUnwrap(sut.cache)
        XCTAssertTrue(images.contains { $0.name == "/usr/lib/dyld" })
    }

    func testRefresh_shouldNotDuplicateImages() throws {
        // -- Arrange --
        sut.start(false)
        let initialImages = try XCTUnwrap(sut.cache)

        // -- Act --
        let refreshedImages = sut.getAllBinaryImages()

        // -- Assert --
        XCTAssertEqual(refreshedImages.count, initialImages.count)
        XCTAssertEqual(Set(refreshedImages.map(\.address)).count, refreshedImages.count)
    }

    func testImageByAddress_shouldFindKSCrashImage() throws {
        // -- Arrange --
        sut.start(false)
        let image = try XCTUnwrap(sut.cache?.first)

        // -- Act --
        let result = sut.imageByAddress(image.address)

        // -- Assert --
        XCTAssertEqual(result?.address, image.address)
    }

    func testImageByAddress_whenSDKCacheMisses_shouldRefreshFromKSCrash() throws {
        // -- Arrange --
        sut.start(false)
        let image = try XCTUnwrap(sut.cache?.first)

        // XCTest can preload all candidate system frameworks, making dlopen-based fixtures
        // unreliable. Model a newly loaded image deterministically: KSCrash knows the image,
        // but the SDK cache does not. This exercises the real provider's cache-miss refresh,
        // not KSCrash's own dynamic-loader notification handling.
        sut.binaryImageRemoved(at: image.address)
        XCTAssertFalse(sut.containsBinaryImage(at: image.address))

        // -- Act --
        let refreshedImage = try XCTUnwrap(sut.imageByAddress(image.address))

        // -- Assert --
        XCTAssertEqual(refreshedImage.address, image.address)
        XCTAssertEqual(refreshedImage.name, image.name)
        XCTAssertEqual(refreshedImage.uuid, image.uuid)
        XCTAssertTrue(sut.containsBinaryImage(at: image.address))
    }
}
#endif // SDK_V10
