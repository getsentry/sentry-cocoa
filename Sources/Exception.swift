//
//  Exception.swift
//  SentrySwift
//
// Created by David Chavez on 25/05/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.exception`
@objc public class Exception: NSObject {
    public let value: String
	public let type: String?
    public let module: String?
	
	public var thread: Thread?

    /// Creates `Exception` object
	@objc public init(value: String, type: String? = nil, module: String? = nil) {
		self.value = value
        self.type = type
        self.module = module
		
		self.thread = nil

        super.init()
    }

    public override func isEqual(_ object: AnyType?) -> Bool {
        let lhs = self
        guard let rhs = object as? Exception else { return false }
        return lhs.type == rhs.type && lhs.value == rhs.value && lhs.module == rhs.module
    }

	internal convenience init?(appleCrashErrorDict: [String: AnyObject], threads: [Thread]? = nil) {
		var type = appleCrashErrorDict["type"] as? String
		var value = appleCrashErrorDict["reason"] as? String
		
		if let theType = type {
			switch theType {
			case "nsexception":
				if let context = appleCrashErrorDict["nsexception"] as? [String: AnyObject] {
					type = context["name"] as? String
					value = context["reason"] as? String ?? value
				}
			case "cpp_exception":
				if let context = appleCrashErrorDict["cpp_exception"] as? [String: AnyObject] {
					type = context["name"] as? String
				}
			case "mach":
				if let context = appleCrashErrorDict["mach"] as? [String: AnyObject],
					let name = context["exception_name"] as? String,
					let exception = context["exception"],
					let code = context["code"],
					let subcode = context["subcode"] {
					type = name
					value = "Exception \(exception), Code \(code), Subcode \(subcode)"
				}
			case "signal":
				if let context = appleCrashErrorDict["signal"] as? [String: AnyObject],
					let name = context["name"] as? String,
					let signal = context["signal"],
					let code = context["code"] {
					type = name
					value = "Signal \(signal), Code \(code)"
				}
			case "user":
				if let context = appleCrashErrorDict["user_reported"] as? [String: AnyObject],
					let name = context["name"] as? String {
					type = name
					// TODO: with custom stack
					// TODO: also platform field for customs stack
				}
			default:
				()
			}
		}
		
		if let value = value {
			self.init(value: value, type: type)
			
			self.thread = threads?.filter({$0.crashed ?? false}).first
		} else {
			SentryLog.Error.log("Crash error could not generate a 'value' based off of information")
			return nil
		}
	}
}

extension Exception: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        return [
            "value": value
        ]
		.set("type", value: type)
        .set("module", value: module)
		.set("thread_id", value: thread?.id)
		.set("stacktrace", value: thread?.stacktrace?.serialized)
    }
}
