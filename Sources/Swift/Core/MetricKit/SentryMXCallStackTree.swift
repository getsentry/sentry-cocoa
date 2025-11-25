import Foundation

#if os(iOS) || os(macOS)
/**
 * JSON specification of MXCallStackTree can be found here https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation
 */
@objcMembers
@_spi(Private) public class SentryMXCallStackTree: NSObject, Codable {
    
    public let callStacks: [SentryMXCallStack]
    public let callStackPerThread: Bool
    
    static func from(data: Data) throws -> SentryMXCallStackTree {
        return try JSONDecoder().decode(SentryMXCallStackTree.self, from: data)
    }
}

@objcMembers
@_spi(Private) public class SentryMXCallStack: NSObject, Codable {
    public let threadAttributed: Bool?
    public let callStackRootFrames: [SentryMXFrame]
    
    public var flattenedRootFrames: [SentryMXFrame] {
        return callStackRootFrames.flatMap { [$0] + $0.frames }
    }
}

@objcMembers
@_spi(Private) public class SentryMXFrame: NSObject, Codable {
    public let binaryUUID: UUID
    public let offsetIntoBinaryTextSegment: Int
    public let binaryName: String?
    public let address: UInt64
    public let subFrames: [SentryMXFrame]?
    public let sampleCount: Int?
    
    var frames: [SentryMXFrame] {
        return (subFrames?.flatMap { [$0] + $0.frames } ?? [])
    }
    
    var framesIncludingSelf: [SentryMXFrame] {
        return [self] + frames
    }
}

#endif
