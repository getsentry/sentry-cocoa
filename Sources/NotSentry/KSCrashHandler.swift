//
//  KSCrashHandler.swift
//  Sentry
//
//  Created by Josh Holtz on 2/2/16.
//
//

import Foundation
import KSCrash

extension SentryClient {
    public func startCrashHandler() {
        crashHandler = KSCrashHandler(client: self)
    }
}

internal typealias CrashDictionary = [String: AnyType]

internal let keyUser = "user"
internal let keyEventTags = "event_tags"
internal let keyEventExtra = "event_extra"
internal let keyBreadcrumbsSerialized = "breadcrumbs_serialized"
internal let keyReleaseVersion = "releaseVersion_serialized"
internal let keyBuildNumber = "buildNumber_serialized"

/// A class to report crashes to Sentry built upon KSCrash
internal final class KSCrashHandler: CrashHandler {
    
    // MARK: - Attributes
    
    private var installation: KSCrashSentryInstallation
    private var isInstalled = false
    
    // MARK: - EventProperties
    
    internal var releaseVersion: String? {
        didSet { updateUserInfo() }
    }
    internal var buildNumber: String? {
        didSet { updateUserInfo() }
    }
    internal var tags: EventTags = [:] {
        didSet { updateUserInfo() }
    }
    internal var extra: EventExtra = [:] {
        didSet { updateUserInfo() }
    }
    internal var user: User? {
        didSet { updateUserInfo() }
    }
    
    required init(client: SentryClient) {
        installation = KSCrashSentryInstallation(client: client)
    }
    
    // MARK: - CrashHandler
    
    internal var breadcrumbsSerialized: BreadcrumbStore.SerializedType? {
        didSet { updateUserInfo() }
    }
    
    /*
     Starts the crash reporting and sends any previously saved crash reports
     - Parameter createdEvent: A closure that passes in a created event
     */
    internal func startCrashReporting() {
        // Sychrnoizes this function
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        guard !isInstalled else { return }
        
        isInstalled = true
        
        // Install
        installation.install()
        
        Log.Debug.log("Started Sentry Client \(SentryClient.versionString)")
        
        sendAllReports()
    }
    
    internal func sendAllReports() {
        // Maps KSCrash reports in `Events`
        #if swift(>=3.0)
            installation.sendAllReports { (filteredReports, _, error) -> Void in
                if error != nil {
                    Log.Error.log("Could not convert crash report to valid event")
                    return
                }
                Log.Debug.log("Sent \(filteredReports?.count) report(s)")
            }
        #else
            installation.sendAllReportsWithCompletion { (filteredReports, completed, error) -> Void in
                if error != nil {
                    Log.Error.log("Could not convert crash report to valid event")
                    return
                }
                Log.Debug.log("Sent \(filteredReports?.count) report(s)")
            }
        #endif
    }
    
    // MARK: - Private Helpers
    
    private func updateUserInfo() {
        var userInfo = CrashDictionary()
        userInfo[keyEventTags] = tags
        userInfo[keyEventExtra] = sanitize(extra)
        userInfo[keyReleaseVersion] = releaseVersion
        userInfo[keyBuildNumber] = buildNumber
        
        if let user = user?.serialized {
            userInfo[keyUser] = user
        }
        
        if let breadcrumbsSerialized = breadcrumbsSerialized {
            userInfo[keyBreadcrumbsSerialized] = breadcrumbsSerialized
        }
        
        KSCrash.sharedInstance().userInfo = userInfo
    }
    
}

private class KSCrashSentryInstallation: KSCrashInstallation {
    
    private let client: SentryClient
    
    init(client: SentryClient) {
        self.client = client
        super.init(requiredProperties: [])
    }
    
    override func sink() -> KSCrashReportFilter! {
        return KSCrashReportSinkSentry(client: client)
    }
    
}

private class KSCrashReportSinkSentry: NSObject, KSCrashReportFilter {
    
    private let client: SentryClient
    
    init(client: SentryClient) {
        self.client = client
        super.init()
    }
    
    @objc func filterReports(_ reports: [AnyType]!, onCompletion: KSCrashReportFilterCompletion!) {
        #if swift(>=3.0)
            DispatchQueue(label: SentryClient.queueName).sync {
                // Mapping reports
                let events: [Event] = reports?
                    .flatMap({ $0 as? CrashDictionary })
                    .flatMap({ CrashReportConverter.convertReportToEvent($0) }) ?? []
            
                if events.isEmpty {
                    onCompletion([], true, SentryError.InvalidCrashReport as NSError)
                    return
                }
            
                let userReported = events.filter({
                    if let exceptions = $0.exceptions, let exception = exceptions.first {
                        return exception.userReported
                    }
                    return false
                })
                
                SentryClient.shared?.stacktraceSnapshot = (
                    threads: userReported.first?.threads?.filter({
                        if let crashed = $0.crashed {
                            return crashed
                        }
                        return false
                    }),
                    debugMeta: userReported.first?.debugMeta
                )
                
                // Sends events recursively
                self.sendEvent(reports, events: events.filter({ !userReported.contains($0) }), success: true, onCompletion: onCompletion)
            }
        #else
            dispatch_sync(dispatch_queue_create(SentryClient.queueName, nil), {
                // Mapping reports
                let events: [Event] = reports?
                    .flatMap({ $0 as? CrashDictionary })
                    .flatMap({ CrashReportConverter.convertReportToEvent($0) }) ?? []
                
                if events.isEmpty {
                    onCompletion([], true, SentryError.InvalidCrashReport as NSError)
                    return
                }
                
                let userReported = events.filter({
                    if let exceptions = $0.exceptions, let exception = exceptions.first {
                        return exception.userReported
                    }
                    return false
                })
            
                SentryClient.shared?.stacktraceSnapshot = (
                    threads: userReported.first?.threads?.filter({
                        if let crashed = $0.crashed {
                            return crashed
                        }
                        return false
                    }),
                    debugMeta: userReported.first?.debugMeta
                )
            
                // Sends events recursively
                self.sendEvent(reports, events: events.filter({ !userReported.contains($0) }), success: true, onCompletion: onCompletion)
            })
        #endif
    }
    
    private func sendEvent(_ reports: [AnyType]!, events allEvents: [Event], success: Bool, onCompletion: KSCrashReportFilterCompletion!) {
        var events = allEvents
        
        // Complete when no more
        guard let event = events.popLast() else {
            onCompletion(reports, success, nil)
            return
        }
        
        // Send event
        // we have to set useClientProperties: false otherwise the event will be mutated before sending
        // but we want to have the state where the event has been stored 
        // see https://github.com/getsentry/sentry-swift/issues/110
        client.captureEvent(event, useClientProperties: false) { [weak self] eventSuccess in
            self?.sendEvent(reports, events: events, success: success && eventSuccess, onCompletion: onCompletion)
        }
    }
    
}
