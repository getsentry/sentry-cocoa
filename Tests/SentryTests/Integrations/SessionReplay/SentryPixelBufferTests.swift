@_spi(Private) @testable import Sentry
import AVFoundation
import CoreVideo
import XCTest

#if os(iOS) || os(tvOS)
final class SentryPixelBufferTests: XCTestCase {

    private final class TestPixelBufferAdapter: SentryPixelBufferAdapter {
        let pixelBufferPool: CVPixelBufferPool?
        private(set) var appendedPixelBuffers = [CVPixelBuffer]()

        init(size: CGSize) {
            var pixelBufferPool: CVPixelBufferPool?
            let attributes: [String: Any] = [
                String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32ARGB,
                String(kCVPixelBufferWidthKey): Int(size.width),
                String(kCVPixelBufferHeightKey): Int(size.height)
            ]
            CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                attributes as CFDictionary,
                &pixelBufferPool
            )
            self.pixelBufferPool = pixelBufferPool
        }

        func append(_ pixelBuffer: CVPixelBuffer, withPresentationTime presentationTime: CMTime) -> Bool {
            appendedPixelBuffers.append(pixelBuffer)
            return true
        }
    }

    func testAppend_whenAppendingMultipleFrames_shouldUseDistinctPixelBuffers() throws {
        // -- Arrange --
        let size = CGSize(width: 2, height: 2)
        let adapter = TestPixelBufferAdapter(size: size)
        let sut = try XCTUnwrap(SentryPixelBuffer(size: size, pixelBufferAdapter: adapter))
        let image = UIGraphicsImageRenderer(size: size).image { _ in }

        // -- Act --
        XCTAssertTrue(sut.append(image: image, presentationTime: .zero))
        XCTAssertTrue(sut.append(image: image, presentationTime: CMTime(value: 1, timescale: 1)))

        // -- Assert --
        XCTAssertEqual(adapter.appendedPixelBuffers.count, 2)
        let firstPixelBuffer = try XCTUnwrap(adapter.appendedPixelBuffers.first)
        let secondPixelBuffer = try XCTUnwrap(adapter.appendedPixelBuffers.last)
        XCTAssertFalse(firstPixelBuffer === secondPixelBuffer)
    }
}
#endif
