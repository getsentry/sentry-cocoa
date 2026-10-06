#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate

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
        if binaryUUID != nil && offsetIntoBinaryTextSegment >= 0 && offsetIntoBinaryTextSegment < address {
            frame.imageAddress = sentry_formatHexAddressUInt64Swift(address - UInt64(offsetIntoBinaryTextSegment))
        }
        return frame
    }
}
#endif
