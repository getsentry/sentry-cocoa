import Foundation

@objc
public class CallStackTree: NSObject, Codable {
    
    public let callStacks: [CallStack]
    public let callStackPerThread: Bool
    
    public init(callStacks: [CallStack], callStackPerThread: Bool) {
        self.callStacks = callStacks
        self.callStackPerThread = callStackPerThread
    }
    
    public static func from(data: Data) throws -> CallStackTree {
        return try JSONDecoder().decode(CallStackTree.self, from: data)
    }
}

@objc
public class CallStack: NSObject, Codable {
    public var threadAttributed: Bool?
    public var callStackRootFrames: [MXFrame]
    
    public var flattenedRootFrames: [MXFrame] {
        return callStackRootFrames.flatMap { [$0] + $0.frames }
    }

    public init(threadAttributed: Bool, rootFrames: [MXFrame]) {
        self.threadAttributed = threadAttributed
        self.callStackRootFrames = rootFrames
    }
}

@objc
public class MXFrame: NSObject, Codable {
    public var binaryUUID: UUID?
    public var offsetIntoBinaryTextSegment: Int?
    public var sampleCount: Int?
    public var binaryName: String?
    public var address: UInt64
    public var subFrames: [MXFrame]?
    
    public init(binaryUUID: UUID? = nil, offsetIntoBinaryTextSegment: Int? = nil, sampleCount: Int? = nil, binaryName: String? = nil, address: UInt64, subFrames: [MXFrame]?) {
        self.binaryUUID = binaryUUID
        self.offsetIntoBinaryTextSegment = offsetIntoBinaryTextSegment
        self.sampleCount = sampleCount
        self.binaryName = binaryName
        self.address = address
        self.subFrames = subFrames
    }
    
    public var frames: [MXFrame] {
        return subFrames?.flatMap { [$0] + $0.frames } ?? []
    }
}
