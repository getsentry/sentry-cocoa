//
//  sentry_cocoa_testApp.swift
//  sentry-cocoa-test
//
//  Created by Denis Andrašec on 26.08.24.
//

import SwiftUI
import Sentry

@main
struct sentry_cocoa_testApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.tracesSampleRate = 1.0
            options.profilesSampleRate = 1.0
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class ProcessTimeManager {
    static let shared = ProcessTimeManager()

    var time: CFTimeInterval = 0
    
    private init() {
        // Initialize or do anything required at the start
        calculateStartTime()
    }

    func timeFromStart() {
        time = timeFromStartToNow()
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    // Called when the app has finished launching
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        ProcessTimeManager.shared.timeFromStart()
        return true
    }
}
