//
//  Thread.swift
//  Sentry
//
//  Created by Josh Holtz on 7/25/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.exception`
@objc(SentryThread) public final class Thread: NSObject {
    public let id: Int
    public var crashed: Bool?
    public let current: Bool?
    public let name: String?
    public let stacktrace: Stacktrace?
    public let reason: String?
    
    /// Creates `Exception` object
    @objc public init(id: Int, crashed: Bool = false, current: Bool = false, name: String? = nil, stacktrace: Stacktrace? = nil, reason: String? = nil) {
        self.id = id
        self.crashed = crashed
        self.current = current
        self.name = name
        self.stacktrace = stacktrace
        self.reason = reason
        
        super.init()
    }
    
    internal convenience init?(appleCrashThreadDict: [String: AnyObject], binaryImages: [BinaryImage]) {
        guard let id = appleCrashThreadDict["index"] as? Int else {
            return nil
        }
        
        let crashed = appleCrashThreadDict["crashed"] as? Bool ?? false
        let current = appleCrashThreadDict["current_thread"] as? Bool ?? false
        let name = appleCrashThreadDict["name"] as? String
        let backtraceDict = appleCrashThreadDict["backtrace"] as? [String: AnyObject]
        let registerDict = appleCrashThreadDict["registers"] as? [String: AnyObject]
        
        let stacktrace = Stacktrace(appleCrashTreadBacktraceDict: backtraceDict,
                                    registerDict: registerDict,
                                    binaryImages: binaryImages)
        stacktrace?.fixDuplicateFrames()
        let reason = Thread.extractCrashReasonFromNotableAddresses(appleCrashThreadDict)
        
        self.init(id: id, crashed: crashed, current: current, name: name, stacktrace: stacktrace, reason: reason)
    }
    
    private static func extractCrashReasonFromNotableAddresses(_ appleCrashThreadDict: [String: AnyObject]) -> String? {
        guard let notableAddresses = appleCrashThreadDict["notable_addresses"] as? [String: AnyObject] else {
            return nil
        }
        
        var crashReasons = Set<String>()
        
        let _ = notableAddresses.filter {
            // we try to find a human readable sentence so we say there should be at least
            // 2 words e.g: unexpectedly found nil while unwrapping an Optional value
            
            let dict = $0.1
            #if swift(>=3.0)
                if let type = dict["type"] as? String, type == "string" {
                    if let value = dict["value"] as? String, value.components(separatedBy: " ").count > 1 {
                        return true
                    }
                }
            #else
                if let type = dict["type"] as? String where type == "string" {
                    if let value = dict["value"] as? String where value.componentsSeparatedByString(" ").count > 1 {
                        return true
                    }
                }
            #endif
            return false
        }.map { _, dict in
            if let value = dict["value"] as? String {
                #if swift(>=3.0)
                    crashReasons.insert(value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                #else
                    crashReasons.insert(value.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
                #endif
            }
        }
        #if swift(>=3.0)
            let result = crashReasons.joined(separator: " | ")
        #else
            let result = crashReasons.joinWithSeparator(" | ")
        #endif
        return result.characters.isEmpty ? nil : result
    }
    
    public override var debugDescription: String {
        return "id: \(id) \n crashed: \(crashed) \n current: \(current) \n name: \(name) \n reason: \(reason) \n stacktrace: \(stacktrace) \n"
    }
}

extension Thread: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        attributes.append(("id", id))
        attributes.append(("crashed", crashed))
        attributes.append(("current", current))
        attributes.append(("name", name))
        attributes.append(("reason", reason))
        attributes.append(("stacktrace", stacktrace?.serialized))
        
        return convertAttributes(attributes)
    }
}
