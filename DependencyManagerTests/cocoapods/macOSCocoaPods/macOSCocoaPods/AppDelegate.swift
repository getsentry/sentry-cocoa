//
//  AppDelegate.swift
//  macOSCocoaPods
//
//  Created by Josh Holtz on 4/25/17.
//  Copyright © 2017 Sentry. All rights reserved.
//

import Cocoa

import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		Client.shared = try? Client(dsn: "https://username:password@app.getsentry.com/12345")
    try? Client.shared?.startCrashHandler()
	}

}

