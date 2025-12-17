@_implementationOnly import _SentryPrivate

// A Sample is the standard data format for a flamegraph taken from https://github.com/brendangregg/FlameGraph
// It is less compact than Apple's MetricKit format, but contains the same data and is easier to work with
struct MXSample {
    let count: Int
    let frames: [MXFrame]
    
    struct MXFrame: Hashable {
        let binaryUUID: UUID
        let offsetIntoBinaryTextSegment: Int
        let binaryName: String?
        let address: UInt64
        
        func toSentryFrame() -> Frame {
            let frame = Frame()
            frame.package = binaryName
            frame.instructionAddress = sentry_formatHexAddressUInt64Swift(address)
            frame.imageAddress = sentry_formatHexAddressUInt64Swift(address - UInt64(offsetIntoBinaryTextSegment))
            return frame
        }
    }
}
