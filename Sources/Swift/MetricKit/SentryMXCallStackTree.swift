import Foundation

#if os(iOS) || os(macOS)
/**
 * JSON specification of MXCallStackTree can be found here https://developer.apple.com/documentation/metrickit/mxcallstacktree/3552293-jsonrepresentation.
 */
@objc
public class SentryMXCallStackTree: NSObject, Codable {
    
    @objc public let callStacks: [SentryMXCallStack]
    @objc public let callStackPerThread: Bool
    
    @objc public init(callStacks: [SentryMXCallStack], callStackPerThread: Bool) {
        self.callStacks = callStacks
        self.callStackPerThread = callStackPerThread
    }
    
    public static func from(data: Data) throws -> SentryMXCallStackTree {
        return try JSONDecoder().decode(SentryMXCallStackTree.self, from: data)
    }
}

@objc
public class SentryMXCallStack: NSObject, Codable {
    public var threadAttributed: Bool?
    public var callStackRootFrames: [SentryMXFrame]
    
    @objc public var flattenedRootFrames: [SentryMXFrame] {
        return callStackRootFrames.flatMap { [$0] + $0.frames }
    }

    public init(threadAttributed: Bool, rootFrames: [SentryMXFrame]) {
        self.threadAttributed = threadAttributed
        self.callStackRootFrames = rootFrames
    }
}

@objc
public class SentryMXFrame: NSObject, Codable {
    public var binaryUUID: UUID
    @objc public var offsetIntoBinaryTextSegment: Int
    @objc public var binaryName: String?
    @objc public var address: UInt64
    public var subFrames: [SentryMXFrame]?
    
    public var sampleCount: Int?
    
    public init(binaryUUID: UUID, offsetIntoBinaryTextSegment: Int, sampleCount: Int? = nil, binaryName: String? = nil, address: UInt64, subFrames: [SentryMXFrame]?) {
        self.binaryUUID = binaryUUID
        self.offsetIntoBinaryTextSegment = offsetIntoBinaryTextSegment
        self.sampleCount = sampleCount
        self.binaryName = binaryName
        self.address = address
        self.subFrames = subFrames
    }
    
    public var frames: [SentryMXFrame] {
        return subFrames?.flatMap { [$0] + $0.frames } ?? []
    }
}

#endif
