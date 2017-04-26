//
//  AppDelegate.swift
//  tvOSCarthage
//
//  Created by Josh Holtz on 4/25/17.
//  Copyright © 2017 Sentry. All rights reserved.
//

import UIKit

import Sentry
import KSCrash
import SentryKSCrash

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		let client = SentryClient(dsnString: "example-dsn")
		client?.startCrashHandler()
		
		return true
	}

}

