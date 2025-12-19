import Foundation

#if os(iOS) || os(macOS)
/**
 * JSON specification of MXCallStackTree can be found here https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation
 */
struct SentryMXCallStackTree: Decodable {
    
    let callStacks: [SentryMXCallStack]
    public let callStackPerThread: Bool
    
    static func from(data: Data) throws -> SentryMXCallStackTree {
        return try JSONDecoder().decode(SentryMXCallStackTree.self, from: data)
    }
}

struct SentryMXCallStack: Decodable {
    let threadAttributed: Bool?
    let callStackRootFrames: [SentryMXFrame]
}

struct SentryMXFrame: Decodable {
    let binaryUUID: UUID
    let offsetIntoBinaryTextSegment: Int
    let binaryName: String?
    let address: UInt64
    let subFrames: [SentryMXFrame]?
    let sampleCount: Int?
}

#endif
