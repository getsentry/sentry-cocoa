/// - SeeAlso: JSON specification of ``MXCallStackTree`` can be found   [here](https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation)
struct SentryMXCallStack: Decodable {
    /// A Boolean indicating that the crash or exception occurred in this call stack.
    let threadAttributed: Bool?

    /// An array of stack frames.
    let callStackRootFrames: [SentryMXFrame]
}
