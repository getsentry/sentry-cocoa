//
//  AppDelegate.swift
//  macOSCarthage
//
//  Created by Josh Holtz on 4/25/17.
//  Copyright © 2017 Sentry. All rights reserved.
//

import Cocoa

import Sentry
import KSCrash
import SentryKSCrash

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let client = SentryClient(dsnString: "example-dsn")
		client?.startCrashHandler()
	}
}

