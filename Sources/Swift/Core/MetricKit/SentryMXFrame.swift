#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

/// - SeeAlso: JSON specification of ``MXCallStackTree`` can be found   [here](https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation)
struct SentryMXFrame: Decodable {
    /// A unique ID a developer uses to symbolicate a stack frame.
    ///
    /// - SeeAlso: For more information, see [Adding identifiable symbol names to a crash report](https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report).
    let binaryUUID: UUID?

    /// The offset of the stack frame into the text segment of the binary.
    let offsetIntoBinaryTextSegment: Int

    /// The name of the binary associated with the stack frame.
    let binaryName: String?

    /// The memory address of the stack frame.
    let address: UInt64

    /// An array of stack frame dictionaries.
    ///
    /// There can be many levels of nested stack frames.
    let subFrames: [SentryMXFrame]?

    /// For a CPU exception, the amount of time spent sampling the stack frame.
    let sampleCount: Int?
}

extension SentryMXFrame {
    func toDebugMeta() -> [DebugMeta] {
        // MetricKit can omit binary metadata while still providing a frame's address and samples.
        guard let binaryUUID else {
            return subFrames?.flatMap { $0.toDebugMeta() } ?? []
        }
        let result = DebugMeta()
        result.type = "macho"
        result.debugID = binaryUUID.uuidString
        result.codeFile = binaryName
        result.imageAddress = SentryMetricKit.imageAddress(address: address, offsetIntoBinaryTextSegment: offsetIntoBinaryTextSegment)
        return [result] + (subFrames?.flatMap { $0.toDebugMeta() } ?? [])
    }

    func toSamples() -> [SentryMXSample] {
        let selfFrame = SentryMXSampleFrame(binaryUUID: binaryUUID, offsetIntoBinaryTextSegment: offsetIntoBinaryTextSegment, binaryName: binaryName, address: address)
        let subframes = subFrames ?? []

        let childCount = subframes.map { $0.sampleCount ?? 0 }.reduce(0, +)
        let selfCount = (sampleCount ?? 0) - childCount
        var result = subframes.flatMap { $0.toSamples() }.map { SentryMXSample(count: $0.count, frames: [selfFrame] + $0.frames) }
        if selfCount > 0 {
            result.append(SentryMXSample(count: selfCount, frames: [selfFrame]))
        }
        return result
    }

    /// Converts this frame to a SentryFrame.
    func toSentryFrameWithTreeData(parentFrameIndex: Int) -> Frame {
        let frame = Frame()
        frame.package = binaryName
        frame.instructionAddress = sentry_formatHexAddressUInt64Swift(address)
        if binaryUUID != nil {
            frame.imageAddress = SentryMetricKit.imageAddress(address: address, offsetIntoBinaryTextSegment: offsetIntoBinaryTextSegment)
        }

        frame.parentIndex = parentFrameIndex as NSNumber
        frame.sampleCount = sampleCount as NSNumber?

        return frame
    }
}

extension SentryMetricKit {
    static func imageAddress(address: UInt64, offsetIntoBinaryTextSegment: Int) -> String? {
        guard offsetIntoBinaryTextSegment >= 0 && offsetIntoBinaryTextSegment < address else {
            return nil
        }
        return sentry_formatHexAddressUInt64Swift(address - UInt64(offsetIntoBinaryTextSegment))
    }
}

#endif
