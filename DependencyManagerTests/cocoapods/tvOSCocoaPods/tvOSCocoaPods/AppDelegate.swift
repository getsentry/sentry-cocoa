//
//  AppDelegate.swift
//  tvOSCocoaPods
//
//  Created by Josh Holtz on 4/25/17.
//  Copyright © 2017 Sentry. All rights reserved.
//

import Sentry

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

		Client.shared = try? Client(dsn: "https://username:password@app.getsentry.com/12345")
    try? Client.shared?.startCrashHandler()

		return true
	}

}

