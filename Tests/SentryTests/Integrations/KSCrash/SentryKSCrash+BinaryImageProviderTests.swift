#if SDK_V10
@_spi(Private) @testable import Sentry
import Darwin
import MachO
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

#if os(iOS) && !targetEnvironment(macCatalyst)
    func testImageByAddress_shouldRefreshAfterDynamicImageLoad() throws {
        // -- Arrange --
        sut.start(false)
        let initialImages = sut.getAllBinaryImages()
        let candidates = [
            (path: "/System/Library/Frameworks/EventKit.framework/EventKit", marker: "EventKit.framework/EventKit"),
            (path: "/System/Library/Frameworks/MapKit.framework/MapKit", marker: "MapKit.framework/MapKit"),
            (path: "/System/Library/Frameworks/PDFKit.framework/PDFKit", marker: "PDFKit.framework/PDFKit"),
            (path: "/usr/lib/libbz2.dylib", marker: "libbz2")
        ]

        for candidate in candidates where !initialImages.contains(where: { $0.name.contains(candidate.marker) }) {
            guard let handle = dlopen(candidate.path, RTLD_NOW | RTLD_LOCAL) else { continue }
            guard let header = imageHeader(containing: candidate.marker) else {
                dlclose(handle)
                continue
            }

            // -- Act --
            let image = sut.imageByAddress(UInt64(UInt(bitPattern: header)))
            dlclose(handle)

            // -- Assert --
            let loadedImage = try XCTUnwrap(image)
            XCTAssertTrue(loadedImage.name.contains(candidate.marker))
            return
        }

        XCTFail("Expected an unloaded dynamic-image fixture to be available")
    }

    private func imageHeader(containing marker: String) -> UnsafePointer<mach_header>? {
        for index in 0..<_dyld_image_count() {
            guard let name = _dyld_get_image_name(index) else { continue }
            if String(cString: name).contains(marker) {
                return _dyld_get_image_header(index)
            }
        }
        return nil
    }
#endif // os(iOS) && !targetEnvironment(macCatalyst)
}
#endif // SDK_V10
