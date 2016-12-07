//
//  Exception.swift
//  SentrySwift
//
// Created by David Chavez on 25/05/16.
//
//

import Foundation

public typealias Mechanism = Dictionary<String, Dictionary<String, String>>

// A class used to represent an exception: `sentry.interfaces.exception`
@objc public final class Exception: NSObject {
    public let value: String
    public let type: String?
    public var mechanism: Mechanism?
    public let module: String?
    public var userReported = false
    
    public var thread: Thread?
    
    /// Creates `Exception` object
    @objc public init(value: String, type: String? = nil, mechanism: Mechanism? = nil, module: String? = nil) {
        self.value = value
        self.type = type
        self.mechanism = mechanism
        self.module = module
        
        self.thread = nil
        
        super.init()
    }
    
    public override func isEqual(_ object: AnyType?) -> Bool {
        let lhs = self
        guard let rhs = object as? Exception else { return false }
        return lhs.type == rhs.type && lhs.value == rhs.value && lhs.module == rhs.module
    }
    
    internal convenience init?(appleCrashErrorDict: [String: AnyObject], threads: [Thread]? = nil, diagnosis: String? = nil) {
        var mechanism = Mechanism()
        
        if let signalDict = appleCrashErrorDict["signal"] as? [String: AnyObject],
            let signal = signalDict["name"] as? String,
            let code = signalDict["code"] as? Int {
            mechanism["posix_signal"] = ["name": signal, "signal": "\(code)"]
        }
        
        if let machDict = appleCrashErrorDict["mach"] as? [String: AnyObject],
            let name = machDict["exception_name"] as? String,
            let exception = machDict["exception"] {
            mechanism["mach_exception"] = ["exception_name": name, "exception": "\(exception)"]
        }
        
        let crashedThread = threads?.filter({$0.crashed ?? false}).first
        
        let (type, value, userReported) = Exception.extractCrashValue(appleCrashErrorDict)
        
        // We prefer diagnosis generated from KSCrash
        if let diagnosis = diagnosis {
            self.init(value: diagnosis, type: type)
        } else if let reason = crashedThread?.reason {
            self.init(value: reason, type: type)
        } else if let value = value {
            self.init(value: value, type: type)
        } else {
            SentryLog.Error.log("Crash error could not generate a 'value' based off of information")
            return nil
        }
        
        self.userReported = userReported
        self.mechanism = mechanism
        self.thread = crashedThread
    }
    
    private static func extractCrashValue(_ appleCrashErrorDict: [String: AnyObject]) -> (String?, String?, Bool) {
        var type = appleCrashErrorDict["type"] as? String
        var value = appleCrashErrorDict["reason"] as? String
        var userReported = false
        
        switch type {
        case "nsexception"?:
            if let context = appleCrashErrorDict["nsexception"] as? [String: AnyObject] {
                type = context["name"] as? String
                value = context["reason"] as? String ?? value
            }
        case "cpp_exception"?:
            if let context = appleCrashErrorDict["cpp_exception"] as? [String: AnyObject] {
                value = context["name"] as? String
            }
        case "mach"?:
            if let context = appleCrashErrorDict["mach"] as? [String: AnyObject],
                let name = context["exception_name"] as? String,
                let exception = context["exception"],
                let code = context["code"],
                let subcode = context["subcode"] {
                type = name
                value = "Exception \(exception), Code \(code), Subcode \(subcode)"
            }
        case "signal"?:
            if let context = appleCrashErrorDict["signal"] as? [String: AnyObject],
                let name = context["name"] as? String,
                let signal = context["signal"],
                let code = context["code"] {
                type = name
                value = "Signal \(signal), Code \(code)"
            }
        case "user"?:
            if let context = appleCrashErrorDict["user_reported"] as? [String: AnyObject],
                let name = context["name"] as? String {
                type = name
                userReported = true
            }
        default:
            value = "UNKNOWN Exception"
        }
        
        return (type: type, value: value, userReported: userReported)
    }
}

extension Exception: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    
    internal var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        attributes.append(("value", value))
        attributes.append(("type", type))
        attributes.append(("mechanism", mechanism))
        attributes.append(("module", module))
        attributes.append(("thread_id", thread?.id))
        attributes.append(("stacktrace", thread?.stacktrace?.serialized))
        
        return convertAttributes(attributes)
    }
}
