#if os(iOS) || os(macOS) || os(visionOS)
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
#endif
