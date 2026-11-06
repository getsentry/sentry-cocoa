#if (!SWIFT_PACKAGE || !SDK_V10) && (os(iOS) || os(macOS))
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) @testable import SentryTestUtils
import _SentryPrivate
import XCTest

final class SentryProfilerSDKBackendValueTests: XCTestCase {
    func testSerializedDebugImages_whenProviderHasImages_shouldReturnWireValues() throws {
        // -- Arrange --
        let container = SentryDependencyContainer.sharedInstance()
        let previousProvider = container.debugImageProvider
        defer { container.debugImageProvider = previousProvider }
        let image = DebugMeta()
        image.debugID = "profiling-debug-id"
        image.codeFile = "profiling-image"
        image.imageAddress = "0x1000"
        image.imageSize = 4_096
        image.type = "macho"
        let provider = TestDebugImageProvider()
        provider.debugImages = [image]
        container.debugImageProvider = provider
        let backend = SentryDefaultProfilerSDKBackend()

        // -- Act --
        let images = try XCTUnwrap(backend.serializedDebugImages())

        // -- Assert --
        XCTAssertEqual(images.count, 1)
        let serialized = try XCTUnwrap(images.first)
        XCTAssertEqual(serialized["debug_id"] as? String, "profiling-debug-id")
        XCTAssertEqual(serialized["code_file"] as? String, "profiling-image")
        XCTAssertEqual(serialized["image_addr"] as? String, "0x1000")
        XCTAssertEqual(serialized["image_size"] as? Int, 4_096)
        XCTAssertEqual(serialized["type"] as? String, "macho")
    }

}
#endif
