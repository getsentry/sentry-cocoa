//
//  SentrySettings.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 28/11/2016.
//
//

import Foundation

class SentrySettings {
    
    private static let automaticBreadcrumbsEnabledKey = "io.sentry.automaticBreadcrumbsEnabled"
    
    #if swift(>=3.0)
    static var automaticBreadcrumbsEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: automaticBreadcrumbsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: automaticBreadcrumbsEnabledKey)
            UserDefaults.standard.synchronize()
        }
    }
    #else
    static var automaticBreadcrumbsEnabled: Bool {
        get {
            return NSUserDefaults.standardUserDefaults().boolForKey(automaticBreadcrumbsEnabledKey)
        }
        set {
            NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: automaticBreadcrumbsEnabledKey)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    #endif
    
}
