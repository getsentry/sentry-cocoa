//
//  Stacktrace.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/22/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.stacktrace.Stacktrace`
@objc public final class Stacktrace: NSObject {
    public let frames: [Frame]
    
    internal convenience init?(appleCrashTreadBacktraceDict: [String: AnyObject]?, binaryImages: [BinaryImage]?) {
        
        guard let appleCrashTreadBacktraceDict = appleCrashTreadBacktraceDict, let binaryImages = binaryImages else {
            return nil
        }
        
        let frames = (appleCrashTreadBacktraceDict["contents"] as? [[String: AnyObject]])?
            .flatMap({ Frame(appleCrashFrameDict: $0, binaryImages: binaryImages) })
        self.init(frames: frames)
        
    }
    
    @objc public init(frames: [Frame]?) {
        self.frames = frames ?? []
    }
    
}

extension Stacktrace: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        #if swift(>=3.0)
        return [:]
            .set("frames", value: frames.reversed().map({ $0.serialized }))
        #else
        return [:]
            .set("frames", value: frames.reverse().map({ $0.serialized }))
        #endif
    }
}
