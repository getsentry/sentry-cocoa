//
//  Stacktrace.swift
//  Sentry
//
//  Created by Josh Holtz on 7/22/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.stacktrace.Stacktrace`
@objc(SentryStacktrace) public final class Stacktrace: NSObject {
    public var frames: [Frame]
    public let register: Register?
    
    internal convenience init?(appleCrashTreadBacktraceDict: [String: AnyObject]?,
                               registerDict: [String: AnyObject]?,
                               binaryImages: [BinaryImage]?) {
        guard let appleCrashTreadBacktraceDict = appleCrashTreadBacktraceDict, let binaryImages = binaryImages else {
            return nil
        }
        
        let frames = (appleCrashTreadBacktraceDict["contents"] as? [[String: AnyObject]])?
            .flatMap({ Frame(appleCrashFrameDict: $0, binaryImages: binaryImages) })
        
        self.init(frames: frames, register: Register(registerDict: registerDict))
    }
    
    @objc public init(frames: [Frame]?) {
        self.frames = frames ?? []
        self.register = nil
    }
    
    @objc public init(frames: [Frame]?, register: Register?) {
        self.frames = frames ?? []
        self.register = register
    }
    
    /// This function fixes duplicate frames and removes the first duplicate 
    /// https://github.com/kstenerud/KSCrash/blob/05cdc801cfc578d256f85de2e72ec7877cbe79f8/Source/KSCrash/Recording/Tools/KSStackCursor_MachineContext.c#L84
    internal func fixDuplicateFrames() {
        guard self.frames.count >= 2 else {
            return
        }
        if self.frames[1].symbolAddress == self.frames[0].symbolAddress && self.register?.registers["lr"] == self.frames[1].instructionAddress {
            #if swift(>=3.0)
            self.frames.remove(at: 1)
            #else
            self.frames.removeAtIndex(1)
            #endif
            Log.Debug.log("Found duplicate frame, removing one with link register")
        }
    }
    
}

extension Stacktrace: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        #if swift(>=3.0)
        attributes.append(("frames", frames.reversed().map({ $0.serialized })))
        #else
        attributes.append(("frames", frames.reverse().map({ $0.serialized })))
        #endif
        
        attributes.append(("registers", register?.registers))
        
        return convertAttributes(attributes)
    }
}

extension Stacktrace {
    
    public static func convertReactNativeStacktrace(_ stacktrace: [[String: AnyObject]]?) -> Stacktrace? {
        guard let stacktrace = stacktrace else { return nil }
        
        var frames: [Frame] = []
        for frame in stacktrace {
            if frame["methodName"] == nil {
                continue
            }
            if let file = frame["file"] as? String {
                #if swift(>=3.0)
                    let simpleFilename = (file as NSString).lastPathComponent.components(separatedBy: "?")[0]
                #else
                    let simpleFilename = (file as NSString).lastPathComponent.componentsSeparatedByString("?")[0]
                #endif
                if let methodName = frame["methodName"] as? String,
                    let lineNumber = frame["lineNumber"] as? Int,
                    let column = frame["column"] as? Int {
                    let frame = Frame(fileName: "app:///\(simpleFilename)",
                        function: methodName,
                        module: nil,
                        line: lineNumber,
                        column: column)
                    frame.platform = "javascript"
                    frames.append(frame)
                }
            }
        }
        
        return Stacktrace(frames: frames)
    }
    
}
