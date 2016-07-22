//
//  ViewController.swift
//  SwiftExample
//
//  Created by Josh Holtz on 3/4/16.
//  Copyright © 2016 RokkinCat. All rights reserved.
//

import UIKit

// Step 1: Import the SentrySwift framework
import SentrySwift

class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Step 1.5: Set logging level to your liking
		SentryClient.logLevel = .Debug
		
		// Step 2: Initialize a SentryClient with your DSN
		// The DSN is in your Sentry project's settings
		SentryClient.shared = SentryClient(dsnString: "")
		
		// OPTIONAL (but super useful)
		// Step 3: Set and start the crash handler
		// This uses KSCrash under the hood
		SentryClient.shared?.startCrashHandler()
		
		// OPTIONAL (but also useful)
		// Step 4: Set any user or global information to be sent up with every exception/message
		// This is optional and can also be done at anytime (so when a user logs in/out)
		SentryClient.shared?.user = User(id: "3",
			email: "example@example.com",
			username: "Example",
			extra: ["is_admin": false]
		)
		// A map or list of tags for this event.
		SentryClient.shared?.tags = [
			"environment": "production"
		]
		// An arbitrary mapping of additional metadata to store with the event
		SentryClient.shared?.extra = [
			"a_thing": 3,
			"some_things": ["green", "red"],
			"foobar": ["foo": "bar"]
		]
		
		// Step 5: Don't make your app perfect so that you can get a crash ;)
		// See the really bad "onClickBreak" function on how to do that
	}

	@IBAction func onClickBreak(sender: AnyObject) {
		SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", to: "point b", from: "point a"))
		
		// Note: You will have to disconnect your app from the debugger to
		// to allow SentrySwift to detect the crash. To do this, kill the app (from Xcode)
		// and then start the app manually in the simulator
		let s: String! = nil
		s.lowercaseString
	}
	
	@IBAction func onClickMessage(sender: AnyObject) {
		// Send a simple message
		SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", message: "Some message", level: .Info, data: ["hehe": "hoho"]))
		SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", to: "point b", from: "point a"))
		SentryClient.shared?.captureMessage("Hehehe, this is totes not useful", level: .Error)
	}
	
	@IBAction func onClickComplexMessage(sender: AnyObject) {
		// Send a customly built event
		SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", url: "www.hammockdesk.com", method: "GET"))
		let event = Event.build("Another example 4") {
			$0.level = .Debug
			$0.tags = ["status": "test"]
			$0.extra = [
				"name": "Josh Holtz",
				"favorite_power_ranger": "green/white"
			]
		}
		SentryClient.shared?.captureEvent(event)
	}
}

