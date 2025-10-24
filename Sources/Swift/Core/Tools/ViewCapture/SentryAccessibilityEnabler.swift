//
//  SentryAccessibilityEnabler.swift
//  Sentry
//
//  Enables accessibility temporarily for redaction purposes.
//  Based on ASAccessibilityEnabler from AccessibilitySnapshot.
//

import Foundation
import Darwin

@objcMembers
public final class SentryAccessibilityEnabler: NSObject {
    private typealias AXSAutomationEnabled = @convention(c) () -> Int32
    private typealias AXSSetAutomationEnabled = @convention(c) (Int32) -> Void

    private var getAutomationEnabled: AXSAutomationEnabled?
    private var setAutomationEnabled: AXSSetAutomationEnabled?
    private var previousValue: Int32 = 0
    private var handle: UnsafeMutableRawPointer?

    public override init() {
        self.getAutomationEnabled = nil
        self.setAutomationEnabled = nil
        self.previousValue = 0
        self.handle = nil
        super.init()
    }

    /// Enables accessibility automation by calling the private _AXSSetAutomationEnabled API.
    /// - Returns: true if accessibility was successfully enabled, false otherwise.
    public func enable() -> Bool {
        if handle != nil {
            // Already loaded
            return true
        }

        // Load the private accessibility dylib
        guard let h = loadDylib(path: "/usr/lib/libAccessibility.dylib") else {
            NSLog("[Sentry] Failed to load libAccessibility.dylib")
            return false
        }
        handle = h

        // Resolve function pointers to private APIs
        guard let symEnabled = dlsym(h, "_AXSAutomationEnabled"),
              let symSetEnabled = dlsym(h, "_AXSSetAutomationEnabled") else {
            NSLog("[Sentry] Failed to find accessibility automation functions")
            dlclose(h)
            handle = nil
            return false
        }

        getAutomationEnabled = unsafeBitCast(symEnabled, to: AXSAutomationEnabled.self)
        setAutomationEnabled = unsafeBitCast(symSetEnabled, to: AXSSetAutomationEnabled.self)

        // Save current state and enable accessibility
        previousValue = getAutomationEnabled?() ?? 0
        setAutomationEnabled?(1)

        return true
    }

    /// Disables accessibility automation and restores the previous state.
    public func disable() {
        guard let handle else {
            // Not enabled
            return
        }

        // Restore previous state
        if let setAutomationEnabled {
            setAutomationEnabled(previousValue)
        }

        // Clean up
        dlclose(handle)
        self.handle = nil
        self.getAutomationEnabled = nil
        self.setAutomationEnabled = nil
    }

    private func loadDylib(path: String) -> UnsafeMutableRawPointer? {
        // Handle simulator vs device paths
        let environment = ProcessInfo.processInfo.environment
        if let simulatorRoot = environment["IPHONE_SIMULATOR_ROOT"] {
            let fullPath = simulatorRoot + path
            return dlopen((fullPath as NSString).fileSystemRepresentation, RTLD_LOCAL)
        } else {
            return dlopen((path as NSString).fileSystemRepresentation, RTLD_LOCAL)
        }
    }

    deinit {
        disable()
    }
}
