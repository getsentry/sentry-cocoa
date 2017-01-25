//
//  Exception.swift
//  SentrySwift
//
// Created by David Chavez on 25/05/16.
//
//

import Foundation

public typealias Mechanism = [String: AnyType]

// A class used to represent an exception: `sentry.interfaces.exception`
@objc(SentryException) public final class Exception: NSObject {
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
        
        if let reason = crashedThread?.reason {
            value = reason
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
        
        if let signalDict = appleCrashErrorDict["signal"] as? [String: AnyType] {
            mechanism["posix_signal"] = [:]
                .set("name", value: signalDict["name"] as? String)
                .set("signal", value: signalDict["signal"] as? Int)
                .set("subcode", value: signalDict["subcode"] as? Int)
                .set("code", value: signalDict["code"] as? Int)
                .set("code_name", value: signalDict["code_name"] as? String)
        }
        
        if let machDict = appleCrashErrorDict["mach"] as? [String: AnyType] {
            mechanism["mach_exception"] = [:]
                .set("exception_name", value: machDict["exception_name"] as? String)
                .set("exception", value: machDict["exception"] as? Int)
                .set("signal", value: machDict["signal"] as? Int)
                .set("code", value: machDict["code"] as? Int)
                .set("subcode", value: machDict["subcode"] as? Int)
        }
        
        if let address = MemoryAddress(appleCrashErrorDict["address"]) {
            if address.asInt() > 0 {
                mechanism["relevant_address"] = address.asHex()
            }
        }
        
        self.mechanism = mechanism
    }
    
    private func extractReason(_ appleCrashErrorDict: [String: AnyObject]) {
        type = appleCrashErrorDict["type"] as? String
        if let reason = appleCrashErrorDict["reason"] as? String {
            value = reason
        }
        
        switch type {
        case "nsexception"?:
            handleNSException(appleCrashErrorDict)
        case "cpp_exception"?:
            handleCPPException(appleCrashErrorDict)
        case "mach"?:
            handleMachException(appleCrashErrorDict)
        case "signal"?:
            handleSignalException(appleCrashErrorDict)
        case "user"?:
            handleUserException(appleCrashErrorDict)
        default:
            value = Exception.defaultReason
        }
    }
    
    private func handleNSException(_ appleCrashErrorDict: [String: AnyObject]) {
        if let context = appleCrashErrorDict["nsexception"] as? [String: AnyObject] {
            type = context["name"] as? String
            value = context["reason"] as? String ?? value
        }
    }
    
    private func handleCPPException(_ appleCrashErrorDict: [String: AnyObject]) {
        if let context = appleCrashErrorDict["cpp_exception"] as? [String: AnyObject],
            let name = context["name"] as? String {
            value = name
        }
    }
    
    private func handleMachException(_ appleCrashErrorDict: [String: AnyObject]) {
        if let context = appleCrashErrorDict["mach"] as? [String: AnyObject],
            let name = context["exception_name"] as? String,
            let exception = context["exception"],
            let code = context["code"],
            let subcode = context["subcode"] {
            type = name
            value = "Exception \(exception), Code \(code), Subcode \(subcode)"
        }
    }
    
    private func handleSignalException(_ appleCrashErrorDict: [String: AnyObject]) {
        if let context = appleCrashErrorDict["signal"] as? [String: AnyObject],
            let name = context["name"] as? String,
            let signal = context["signal"],
            let code = context["code"] {
            type = name
            value = "Signal \(signal), Code \(code)"
        }
    }
    
    private func handleUserException(_ appleCrashErrorDict: [String: AnyObject]) {
        userReported = false
        
        if let context = appleCrashErrorDict["user_reported"] as? [String: AnyObject],
            let name = context["name"] as? String,
            let language = context["language"] as? String {
            type = name
            if language == SentryClient.CrashLanguages.reactNative { // We use this syntax here because dont want to have swift 3.0 #if
                if let backtrace = context["backtrace"] as? [[String: AnyObject]] {
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
