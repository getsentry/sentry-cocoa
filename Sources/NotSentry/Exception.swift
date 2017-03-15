//
//  Exception.swift
//  Sentry
//
// Created by David Chavez on 25/05/16.
//
//

import Foundation

public typealias Mechanism = [String: AnyType]

// A class used to represent an exception: `sentry.interfaces.exception`
@objc(SentryException) public final class Exception: NSObject {
    typealias ReactNativeInfo = (address: UInt, stacktrace: Stacktrace)
    
    static let defaultReason = "UNKNOWN Exception"
    public var value: String
    public var type: String?
    public var mechanism: Mechanism?
    public var module: String?
    public var userReported = false
    public var thread: Thread?
    private var userInfo: CrashReportConverter.UserInfo?
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
    
    internal convenience init(appleCrashErrorDict: [String: AnyObject], userInfo: CrashReportConverter.UserInfo) {
        self.init(value: Exception.defaultReason)
        
        extractMechanism(appleCrashErrorDict)
        extractReason(appleCrashErrorDict)
        self.userInfo = userInfo
    }
    
    func update(ksCrashDiagnosis diagnosis: String?) {
        if let diagnosis = diagnosis {
            value = diagnosis
        }
    }

    private func reactNativeStacktrace() -> ReactNativeInfo? {
        guard let userInfo = userInfo else { return nil }
        guard let nativeStracktrace = userInfo.extra?["__sentry_stack"] as? [[String: AnyObject]] else { return nil }
        guard let address = userInfo.extra?["__sentry_address"] as? UInt else { return nil }
        guard let stacktrace = Stacktrace.convertReactNativeStacktrace(nativeStracktrace) else { return nil }
        return ReactNativeInfo(address: address, stacktrace: stacktrace)
    }
    
    private func indexOfReactNativeCallFrame(crashedThreadFrames: [Frame]?, nativeCallAddress: UInt) -> Int? {
        guard let frames = crashedThreadFrames else { return nil }
        var smallestDiff: UInt = UInt.max
        var index = -1
        var counter = 0
        for frame in frames {
            if let instructionAddress = MemoryAddress(frame.instructionAddress)?.asInt() {
                if instructionAddress < nativeCallAddress {
                    continue
                }
                let diff = instructionAddress - nativeCallAddress
                if diff < smallestDiff {
                    smallestDiff = diff
                    index = counter
                }
                counter += 1
            }
        }
        return index > -1 ? index + 1 : nil
    }
    
    #if swift(>=3.0)
    func update(threads: inout [Thread]) {
        var crashedThread = threads.first(where: { $0.crashed ?? false })
        
        if let stacktrace = userStacktrace {
            let reactNativeThread = Thread(id: 99, crashed: true, current: true, name: "React Native", stacktrace: stacktrace, reason: type)
            _ = threads.map({ $0.crashed = false })
            threads.append(reactNativeThread)
            crashedThread = reactNativeThread
        }
        
        if let reason = crashedThread?.reason {
            value = reason
        }
        
        if let reactNativeInfo = reactNativeStacktrace(),
            let indexOfFrame = indexOfReactNativeCallFrame(crashedThreadFrames: crashedThread?.stacktrace?.frames,
                                                           nativeCallAddress: reactNativeInfo.address) {
            for frame in reactNativeInfo.stacktrace.frames.reversed() {
                crashedThread?.stacktrace?.frames.insert(frame, at: indexOfFrame + 1)
            }
        }
        
        thread = crashedThread
    }
    #else
    func update(inout threads threads: [Thread]) {
        var crashedThread = threads.filter({ $0.crashed ?? false }).first
    
        if let stacktrace = userStacktrace {
            let reactNativeThread = Thread(id: 99, crashed: true, current: true, name: "React Native", stacktrace: stacktrace, reason: type)
            _ = threads.map({ $0.crashed = false })
            threads.append(reactNativeThread)
            crashedThread = reactNativeThread
        }
    
        if let reason = crashedThread?.reason {
            value = reason
        }
    
        if let reactNativeInfo = reactNativeStacktrace(),
            let indexOfFrame = indexOfReactNativeCallFrame(crashedThread?.stacktrace?.frames,
                                                           nativeCallAddress: reactNativeInfo.address) {
            for frame in reactNativeInfo.stacktrace.frames.reverse() {
                crashedThread?.stacktrace?.frames.insert(frame, atIndex: indexOfFrame + 1)
            }
        }
    
        thread = crashedThread
    }
    #endif
    
    private func extractMechanism(_ appleCrashErrorDict: [String: AnyObject]) {
        var mechanism = Mechanism()
        
        if let signalDict = appleCrashErrorDict["signal"] as? [String: AnyType] {
            var posixSignal: [Attribute] = []
            posixSignal.append(("name", signalDict["name"] as? String))
            posixSignal.append(("signal", signalDict["signal"] as? Int))
            posixSignal.append(("subcode", signalDict["subcode"] as? Int))
            posixSignal.append(("code", signalDict["code"] as? Int))
            posixSignal.append(("code_name", signalDict["code_name"] as? String))
            mechanism["posix_signal"] = convertAttributes(posixSignal)
        }
        
        if let machDict = appleCrashErrorDict["mach"] as? [String: AnyType] {
            var machException: [Attribute] = []
            machException.append(("exception_name", machDict["exception_name"] as? String))
            machException.append(("exception", machDict["exception"] as? Int))
            machException.append(("signal", machDict["signal"] as? Int))
            machException.append(("subcode", machDict["subcode"] as? Int))
            machException.append(("code", machDict["code"] as? Int))
            mechanism["mach_exception"] = convertAttributes(machException)
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
