//
//  AppDelegate.swift
//  MacExampleSwift
//
//  Created by Daniel Griesser on 03.04.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

import Cocoa
import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        _ = SentrySDK(options: [
            "dsn": "",
            "debug": true
        ])
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

