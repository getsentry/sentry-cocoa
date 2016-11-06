//
//  Thread.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/25/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.exception`
@objc public class Thread: NSObject {
	public let id: Int
	public let crashed: Bool?
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
		
		let stacktrace = Stacktrace(appleCrashTreadBacktraceDict: backtraceDict, binaryImages: binaryImages)
        
        #if swift(>=3.0)
            let reason = Thread.extractCrashReasonFromNotableAddresses(appleCrashThreadDict: appleCrashThreadDict)
        #else
            let reason = Thread.extractCrashReasonFromNotableAddresses(appleCrashThreadDict)
        #endif
        
		self.init(id: id, crashed: crashed, current: current, name: name, stacktrace: stacktrace, reason: reason)
	}
    
    private static func extractCrashReasonFromNotableAddresses(appleCrashThreadDict: [String: AnyObject]) -> String? {
        guard let notableAddresses = appleCrashThreadDict["notable_addresses"] as? Dictionary<String, AnyObject> else {
            return nil
        }
        
        #if swift(>=3.0)
            return notableAddresses.reduce(nil as String?) {prev, notableAddress in
                let dict = notableAddress.1
                if let type = dict["type"] as? String, type == "string" {
                    if let prev = prev,
                        let value = dict["value"] as? String,
                        value.components(separatedBy: " ").count > 3 {
                        return "\(prev)\(value) "
                    }
                }
                return prev
            }
        #else
            return notableAddresses.reduce(nil as String?) {prev, notableAddress in
                let dict = notableAddress.1
                if let type = dict["type"] as? String where type == "string" {
                    if let prev = prev,
                        let value = dict["value"] as? String
                        where value.componentsSeparatedByString(" ").count > 3 {
                        return "\(prev)\(value) "
                    }
                }
                return prev
            }
        #endif
    }
    
    public override var debugDescription: String {
        return "id: \(id) \n crashed: \(crashed) \n current: \(current) \n name: \(name) \n reason: \(reason) \n stacktrace: \(stacktrace) \n"
    }
}

extension Thread: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [
			"id": id,
			]
			.set("crashed", value: crashed)
			.set("current", value: current)
			.set("name", value: name)
            .set("reason", value: reason)
			.set("stacktrace", value: stacktrace?.serialized)
	}
}
