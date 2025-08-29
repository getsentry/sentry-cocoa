// Adapted from
// https://github.com/bugsnag/bugsnag-cocoa/blob/2f373f21b965f1b13d7070662e2d35f46c17d975/Bugsnag/Delivery/BSGConnectivity.m
//
//  Created by Jamie Lynch on 2017-09-04.
//
//  Copyright (c) 2017 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation

#if !os(watchOS) && !(os(visionOS) && !canImport(UIKit))
import SystemConfiguration

@objc
public enum SentryConnectivity: Int {
    case cellular
    case wiFi
    case none
    
    func toString() -> String {
        switch self {
        case .cellular:
            return "cellular"
        case .wiFi:
            return "wifi"
        case .none:
            return "none"
        }
    }
}

private let kSCNetworkReachabilityFlagsUninitialized: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: UInt32.max)

private var sentryReachabilityObservers = NSHashTable<SentryReachabilityObserver>.weakObjects()
private var sentryCurrentReachabilityState: SCNetworkReachabilityFlags = kSCNetworkReachabilityFlagsUninitialized
private var sentryReachabilityQueue: DispatchQueue?

#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
private var sentryReachabilityIgnoreActualCallback = false

@objc public class SentryReachabilityTestHelper: NSObject {
    @objc static public func setReachabilityIgnoreActualCallback(_ value: Bool) {
        SentrySDKLog.debug("Setting ignore actual callback to \(value)")
        sentryReachabilityIgnoreActualCallback = value
    }
    
    @objc static public func connectivityCallback(_ flags: SCNetworkReachabilityFlags) {
        sentryConnectivityCallback(flags)
    }
    
    @objc static public func connectivityFlagRepresentation(_ flags: SCNetworkReachabilityFlags) -> String {
        sentryConnectivityFlagRepresentation(flags)
    }
    
    @objc static public func stringForSentryConnectivity(_ type: SentryConnectivity) -> String {
        type.toString()
    }
}
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI

public func sentryConnectivityCallback(_ flags: SCNetworkReachabilityFlags) {
    objc_sync_enter(sentryReachabilityObservers)
    defer { objc_sync_exit(sentryReachabilityObservers) }
    
    SentrySDKLog.debug("Entered synchronized region of SentryConnectivityCallback with flags: \(flags.rawValue)")
    
    guard sentryReachabilityObservers.count > 0 else {
        SentrySDKLog.debug("No reachability observers registered. Nothing to do.")
        return
    }
    
    guard sentryConnectivityShouldReportChange(flags) else {
        SentrySDKLog.debug("SentryConnectivityShouldReportChange returned false for flags \(flags.rawValue), will not report change to observers.")
        return
    }
    
    let connected = flags.contains(.reachable)
    
    SentrySDKLog.debug("Notifying observers...")
    for observer in sentryReachabilityObservers.allObjects {
        SentrySDKLog.debug("Notifying \(observer)")
        observer.connectivityChanged(connected, typeDescription: sentryConnectivityFlagRepresentation(flags))
    }
    SentrySDKLog.debug("Finished notifying observers.")
}

public func sentryConnectivityShouldReportChange(_ flags: SCNetworkReachabilityFlags) -> Bool {
#if canImport(UIKit)
    let importantFlags: SCNetworkReachabilityFlags = [.isWWAN, .reachable]
#else
    let importantFlags: SCNetworkReachabilityFlags = .reachable
#endif // canImport(UIKit)
    
    let newFlags = SCNetworkReachabilityFlags(rawValue: flags.rawValue & importantFlags.rawValue)
    if newFlags == sentryCurrentReachabilityState {
        SentrySDKLog.debug("No change in reachability state. SentryConnectivityShouldReportChange will return false for flags \(flags.rawValue), sentryCurrentReachabilityState \(sentryCurrentReachabilityState.rawValue)")
        return false
    }
    
    sentryCurrentReachabilityState = newFlags
    return true
}

public func sentryConnectivityFlagRepresentation(_ flags: SCNetworkReachabilityFlags) -> String {
    let connected = flags.contains(.reachable)
#if canImport(UIKit)
    if connected {
        return flags.contains(.isWWAN) ? SentryConnectivity.cellular.toString() : SentryConnectivity.wiFi.toString()
    } else {
        return SentryConnectivity.none.toString()
    }
#else
    return connected ? SentryConnectivity.wiFi.toString() : SentryConnectivity.none.toString()
#endif // canImport(UIKit)
}

private func sentryConnectivityActualCallback(
    _ target: SCNetworkReachability,
    _ flags: SCNetworkReachabilityFlags,
    _ info: UnsafeMutableRawPointer?
) {
    SentrySDKLog.debug("SentryConnectivityCallback called with target: \(target); flags: \(flags.rawValue)")
    
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    if sentryReachabilityIgnoreActualCallback {
        SentrySDKLog.debug("Ignoring actual callback.")
        return
    }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    
    sentryConnectivityCallback(flags)
}

@_spi(Private) @objc public protocol SentryReachabilityObserver: NSObjectProtocol {
    @objc func connectivityChanged(_ connected: Bool, typeDescription: String)
}

@_spi(Private) @objc public class SentryReachability: NSObject {
    private var sentryReachabilityRef: SCNetworkReachability?
    
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    @objc public var skipRegisteringActualCallbacks = false
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    
    @objc(addObserver:)
    public func add(_ observer: SentryReachabilityObserver) {
        SentrySDKLog.debug("Adding observer: \(observer)")
        
        objc_sync_enter(sentryReachabilityObservers)
        defer { objc_sync_exit(sentryReachabilityObservers) }
        
        SentrySDKLog.debug("Synchronized to add observer: \(observer)")
        
        if sentryReachabilityObservers.contains(observer) {
            SentrySDKLog.debug("Observer already added. Doing nothing.")
            return
        }
        
        sentryReachabilityObservers.add(observer)
        
        if sentryReachabilityObservers.count > 1 {
            return
        }
        
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if skipRegisteringActualCallbacks {
            SentrySDKLog.debug("Skip registering actual callbacks")
            return
        }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        
        sentryReachabilityQueue = DispatchQueue(label: "io.sentry.cocoa.connectivity")
        
        guard let reachabilityRef = SCNetworkReachabilityCreateWithName(nil, "sentry.io") else {
            return
        }
        
        sentryReachabilityRef = reachabilityRef
        
        SentrySDKLog.debug("registering callback for reachability ref \(reachabilityRef)")
        
        var context = SCNetworkReachabilityContext(
            version: 0,
            info: nil,
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        SCNetworkReachabilitySetCallback(reachabilityRef, sentryConnectivityActualCallback, &context)
        SCNetworkReachabilitySetDispatchQueue(reachabilityRef, sentryReachabilityQueue)
    }
    
    @objc(removeObserver:)
    public func remove(_ observer: SentryReachabilityObserver) {
        SentrySDKLog.debug("Removing observer: \(observer)")
        
        objc_sync_enter(sentryReachabilityObservers)
        defer { objc_sync_exit(sentryReachabilityObservers) }
        
        SentrySDKLog.debug("Synchronized to remove observer: \(observer)")
        sentryReachabilityObservers.remove(observer)
        
        if sentryReachabilityObservers.count == 0 {
            unsetReachabilityCallback()
        }
    }
    
    @objc public func removeAllObservers() {
        SentrySDKLog.debug("Removing all observers.")
        
        objc_sync_enter(sentryReachabilityObservers)
        defer { objc_sync_exit(sentryReachabilityObservers) }
        
        SentrySDKLog.debug("Synchronized to remove all observers.")
        sentryReachabilityObservers.removeAllObjects()
        unsetReachabilityCallback()
    }
    
    private func unsetReachabilityCallback() {
#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if skipRegisteringActualCallbacks {
            SentrySDKLog.debug("Skip unsetting actual callbacks")
        }
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        
        sentryCurrentReachabilityState = kSCNetworkReachabilityFlagsUninitialized
        
        if let reachabilityRef = sentryReachabilityRef {
            SentrySDKLog.debug("removing callback for reachability ref \(reachabilityRef)")
            SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
            SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
            sentryReachabilityRef = nil
        }
        
        SentrySDKLog.debug("Cleaning up reachability queue.")
        sentryReachabilityQueue = nil
    }
    
    deinit {
        removeAllObservers()
    }
}

#endif // !os(watchOS) && !(os(visionOS) && !canImport(UIKit))
