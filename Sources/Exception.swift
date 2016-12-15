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
    static let defaultReason = "UNKNOWN Exception"
    public var value: String
    public var type: String?
    public var mechanism: Mechanism?
    public var module: String?
    public var userReported = false
    public var thread: Thread?
    
    private var userStacktrace: Stacktrace?
    
    /// Creates `Exception` object
    @objc public init(value: String, type: String? = nil, mechanism: Mechanism? = nil, module: String? = nil) {
        self.value = value
        self.type = type
        self.mechanism = mechanism
        self.module = module
        super.init()
    }
    
    public override func isEqual(_ object: AnyType?) -> Bool {
        let lhs = self
        guard let rhs = object as? Exception else { return false }
        return lhs.type == rhs.type && lhs.value == rhs.value && lhs.module == rhs.module
    }
    
    internal convenience init(appleCrashErrorDict: [String: AnyObject]) {
        self.init(value: Exception.defaultReason)
        
        extractMechanism(appleCrashErrorDict)
        extractReason(appleCrashErrorDict)
    }
    
    func update(ksCrashDiagnosis diagnosis: String?) {
        if let diagnosis = diagnosis {
            value = diagnosis
        }
    }
    
    #if swift(>=3.0)
    func update(threads: inout [Thread]) {
        var crashedThread = threads.filter({ $0.crashed ?? false }).first
        
        if let stacktrace = userStacktrace {
            let reactNativeThread = Thread(id: 99, crashed: true, current: true, name: "React Native", stacktrace: stacktrace, reason: type)
            threads.append(reactNativeThread)
            crashedThread = reactNativeThread
        }
        
        if value == Exception.defaultReason {
            if let reason = crashedThread?.reason {
                value = reason
            }
        }
        
        thread = crashedThread
    }
    #else
    func update(inout threads threads: [Thread]) {
        var crashedThread = threads.filter({ $0.crashed ?? false }).first
        
        if let stacktrace = userStacktrace {
            let reactNativeThread = Thread(id: 99, crashed: true, current: true, name: "React Native", stacktrace: stacktrace, reason: type)
            threads.append(reactNativeThread)
            crashedThread = reactNativeThread
        }
        
        if let reason = crashedThread?.reason {
            value = reason
        }
        
        thread = crashedThread
    }
    #endif
    
    private func extractMechanism(_ appleCrashErrorDict: [String: AnyObject]) {
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
        
        self.mechanism = mechanism
    }
    
    private func extractReason(_ appleCrashErrorDict: [String: AnyObject]) {
        type = appleCrashErrorDict["type"] as? String
        value = "\(appleCrashErrorDict["reason"])"
        
        switch type {
        case "nsexception"?:
            if let context = appleCrashErrorDict["nsexception"] as? [String: AnyObject] {
                type = context["name"] as? String
                value = context["reason"] as? String ?? value
            }
        case "cpp_exception"?:
            if let context = appleCrashErrorDict["cpp_exception"] as? [String: AnyObject] {
                value = "\(context["name"])"
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
            handleUserException(appleCrashErrorDict)
        default:
            value = Exception.defaultReason
        }
    }
    
    private func handleUserException(_ appleCrashErrorDict: [String: AnyObject]) {
        userReported = false
        
        if let context = appleCrashErrorDict["user_reported"] as? [String: AnyObject],
            let name = context["name"] as? String,
            let language = context["language"] as? String {
            type = name
            if language == SentryClient.CrashLanguages.reactNative { // We use this syntax here because dont want to have swift 3.0 #if
                if let backtrace = context["backtrace"] as? [Dictionary<String, AnyObject>] {
                    userStacktrace = Stacktrace.convertReactNativeStacktrace(backtrace)
                }
            } else {
                userReported = true
            }
        }
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
