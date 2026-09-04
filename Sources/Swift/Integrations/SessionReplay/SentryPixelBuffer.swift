#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)

import AVFoundation
import CoreGraphics
import Foundation
import UIKit

protocol SentryAppendablePixelBuffer {
    func append(image: UIImage, presentationTime: CMTime) -> Bool
}

protocol SentryPixelBufferAdapter {
    var pixelBufferPool: CVPixelBufferPool? { get }
    func append(_ pixelBuffer: CVPixelBuffer, withPresentationTime presentationTime: CMTime) -> Bool
}

extension AVAssetWriterInputPixelBufferAdaptor: SentryPixelBufferAdapter {}

final class SentryPixelBuffer: SentryAppendablePixelBuffer {
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let size: CGSize
    private let pixelBufferAdapter: SentryPixelBufferAdapter

    convenience init?(size: CGSize, videoWriterInput: AVAssetWriterInput) {
        // AVFoundation requires a complete buffer description before it can create the pool.
        let bufferAttributes: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32ARGB,
            String(kCVPixelBufferWidthKey): Int(size.width),
            String(kCVPixelBufferHeightKey): Int(size.height)
        ]
        let pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: bufferAttributes
        )
        self.init(size: size, pixelBufferAdapter: pixelBufferAdapter)
    }

    init?(size: CGSize, pixelBufferAdapter: SentryPixelBufferAdapter) {
        self.size = size
        self.pixelBufferAdapter = pixelBufferAdapter
    }

    func append(image: UIImage, presentationTime: CMTime) -> Bool {
        SentrySDKLog.debug("[Session Replay] Appending image to pixel buffer with presentation time: \(presentationTime)")
        guard let pixelBufferPool = pixelBufferAdapter.pixelBufferPool else {
            SentrySDKLog.error("[Session Replay] Could not append image to pixel buffer, reason: pixel buffer pool is nil")
            return false
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            SentrySDKLog.error("[Session Replay] Could not append image to pixel buffer, reason: pixel buffer creation failed with status \(status)")
            return false
        }

        // AVFoundation retains appended buffers while encoding, so later frames need independent storage.
        guard draw(image: image, into: pixelBuffer) else { return false }
        return pixelBufferAdapter.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    private func draw(image: UIImage, into pixelBuffer: CVPixelBuffer) -> Bool {
        // The CPU modifies the base address, so a read-only lock could leave Core Video caches stale.
        let status = CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard status == kCVReturnSuccess else {
            SentrySDKLog.error("[Session Replay] Failed to append image to pixel buffer, reason: could not lock pixel buffer with status \(status)")
            return false
        }
        // Keep lock ownership balanced when image conversion exits early.
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        guard
            let cgimage = image.cgImage,
            let context = CGContext(
                data: pixelData,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: rgbColorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            ) else {
            SentrySDKLog.error("[Session Replay] Failed to append image to pixel buffer, reason: could not create CGContext")
            return false
        }

        context.draw(cgimage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return true
    }
}
#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
