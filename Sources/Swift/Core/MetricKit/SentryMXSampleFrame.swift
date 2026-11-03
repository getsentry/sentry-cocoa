#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

struct SentryMXSampleFrame: Hashable {
    let binaryUUID: UUID?
    let offsetIntoBinaryTextSegment: Int
    let binaryName: String?
    let address: UInt64
}

extension SentryMXSampleFrame {
    func toSentryFrame() -> Frame {
        let frame = Frame()
        frame.package = binaryName
        frame.instructionAddress = sentry_formatHexAddressUInt64Swift(address)
        if binaryUUID != nil {
            frame.imageAddress = SentryMetricKit.imageAddress(address: address, offsetIntoBinaryTextSegment: offsetIntoBinaryTextSegment)
        }
        return frame
    }
}
#endif
