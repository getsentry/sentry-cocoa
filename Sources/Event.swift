//
//  Event.swift
//  SentrySwift
//
//  Created by Josh Holtz on 12/16/15.
//
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
#endif

public typealias EventTags = [String: String]
public typealias EventModules = [String: String]
public typealias EventExtra = [String: AnyType]
public typealias EventFingerprint = [String]

// This is declared here to keep namespace compatibility with objc
@objc(SentrySeverity) public enum Severity: Int, CustomStringConvertible {
    case Fatal, Error, Warning, Info, Debug
    
    public var description: String {
        switch self {
        case .Fatal: return "fatal"
        case .Error: return "error"
        case .Warning: return "warning"
        case .Info: return "info"
        case .Debug: return "debug"
        }
    }
}

/// A class that defines an event to be reported
@objc(SentryEvent) public final class Event: NSObject, EventProperties {
    
    public typealias BuildEvent = (inout Event) -> Void
    internal typealias StacktraceSnapshot = (threads: [Thread]?, debugMeta: DebugMeta?)
    
    // MARK: - Required Attributes
    
    #if swift(>=3.0)
    public let eventID: String = NSUUID().uuidString.replacingOccurrences(of: "-", with: "")
    #else
    public let eventID: String = NSUUID().UUIDString.stringByReplacingOccurrencesOfString("-", withString: "")
    #endif
    public var message: String
    public var timestamp: NSDate = NSDate()
    public var level: Severity = .Error
    public var platform: String = "cocoa"
    
    // MARK: - Optional Attributes
    
    public var logger: String?
    public var culprit: String?
    public var serverName: String?
    public var releaseVersion: String?
    public var buildNumber: String?
    public var tags: EventTags = [:]
    public var modules: EventModules?
    public var extra: EventExtra = [:]
    public var fingerprint: EventFingerprint?
    
    // MARK: - Optional Interfaces
    
    public var user: User?
    public var threads: [Thread]?
    public var exceptions: [Exception]?
    public var stacktrace: Stacktrace?
    internal var breadcrumbsSerialized: BreadcrumbStore.SerializedType?
    
    internal var debugMeta: DebugMeta?
  
    /*
     Creates an event
     - Parameter message: A message
     - Parameter build: A closure that passes an event to build upon
     */
    public static func build(_ message: String, build: BuildEvent) -> Event {
        var event: Event = Event(message, timestamp: NSDate())
        build(&event)
        return event
    }
    
    /*
     Creates an event
     - Parameter message: A message
     - Parameter timestamp: A timestamp
     - Parameter level: A severity level
     - Parameter platform: A platform
     - Parameter logger: A logger
     - Parameter culprit: A culprit
     - Parameter serverName: A server name
     - Parameter release: A release
     - Parameter buildNumber: A buildNumber
     - Parameter tags: A dictionary of tags
     - Parameter modules: A dictionary of modules
     - Parameter extras: A dictionary of extras
     - Parameter fingerprint: A array of fingerprints
     - Parameter user: A user object
     - Parameter exceptions: An array of `Exception` objects
     - Parameter stacktrace: An array of `Stacktrace` objects
     */
    @objc public init(_ message: String,
                      timestamp: NSDate = NSDate(),
                      level: Severity = .Error,
                      logger: String? = nil,
                      culprit: String? = nil,
                      serverName: String? = nil,
                      release: String? = nil,
                      buildNumber: String? = nil,
                      tags: EventTags = [:],
                      modules: EventModules? = nil,
                      extra: EventExtra = [:],
                      fingerprint: EventFingerprint? = nil,
                      user: User? = nil,
                      exceptions: [Exception]? = nil,
                      stacktrace: Stacktrace? = nil) {
        
        // Required
        self.message = message
        self.timestamp = timestamp
        self.level = level
        
        // Optional
        self.logger = logger
        self.culprit = culprit
        self.serverName = serverName
        self.releaseVersion = release
        self.buildNumber = buildNumber
        self.tags = tags
        self.modules = modules
        self.extra = extra
        self.fingerprint = fingerprint
        
        // Optional Interfaces
        self.user = user
        self.exceptions = exceptions
        self.stacktrace = stacktrace
        
        super.init()
    }
    
    /// This will set threads and debugMeta if not nil with snapshot of stacktrace if called
    /// SentryClient.shared?.snapshotStacktrace()
    public func fetchStacktrace() {
        if threads == nil {
            threads = SentryClient.shared?.stacktraceSnapshot?.threads
        }
        if debugMeta == nil {
            debugMeta = SentryClient.shared?.stacktraceSnapshot?.debugMeta
        }
    }
}

extension Event: EventSerializable {
    typealias SerializedType = SerializedTypeDictionary
    
    var sdk: [String: String]? {
        return [
            "name": "sentry-swift",
            "version": SentryClient.Info.version
        ]
    }
    
    /// Dictionary version of attributes set in event
    var serialized: SerializedType {
        
        // Create attributes list
        var attributes: [Attribute] = []
        
        // Required
        attributes.append(("event_id", eventID))
        attributes.append(("message", message))
        attributes.append(("timestamp", timestamp.iso8601))
        attributes.append(("level", level.description))
        attributes.append(("platform", platform))
        // Computed
        attributes.append(("sdk", sdk))
        attributes.append(("contexts", Contexts().serialized))
        // Optional
        attributes.append(("logger", logger))
        attributes.append(("culprit", culprit))
        attributes.append(("server_name", serverName))
        attributes.append(("release", releaseVersion))
        attributes.append(("build_number", buildNumber))
        attributes.append(("modules", modules))
        attributes.append(("fingerprint", fingerprint))
        
        if JSONSerialization.isValidJSONObject(tags) {
            attributes.append(("tags", tags))
        } else if !tags.isEmpty {
            Log.Error.log("event.tags is no valid json object, discarding it -> Check NSJSONSerialization.isValidJSONObject")
        }
        
        if JSONSerialization.isValidJSONObject(extra) {
            attributes.append(("extra", extra))
        } else if !extra.isEmpty {
            Log.Error.log("event.extra is no valid json object, discarding it -> Check NSJSONSerialization.isValidJSONObject")
        }
        
        // Interfaces
        attributes.append(("user", user?.serialized))
        attributes.append(("threads", [:].set("values", value: threads?.map { $0.serialized })))
        attributes.append(("exception", [:].set("values", value: exceptions?.map { $0.serialized })))
        attributes.append(("breadcrumbs", breadcrumbsSerialized))
        attributes.append(("stacktrace", stacktrace?.serialized))
        attributes.append(("debug_meta", debugMeta?.serialized))
        
        return convertAttributes(attributes)
    }
}
