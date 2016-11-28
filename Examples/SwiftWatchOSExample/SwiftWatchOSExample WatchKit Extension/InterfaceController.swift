//
//  InterfaceController.swift
//  SwiftWatchOSExample WatchKit Extension
//
//  Created by Daniel Griesser on 14/11/16.
//  Copyright © 2016 Sentry. All rights reserved.
//

import WatchKit
import Foundation

// Step 1: Import the SentrySwift framework
import SentrySwift

class InterfaceController: WKInterfaceController {

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        
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
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func onClickBreak() {
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", to: "point b", from: "point a"))
        
        NSException(name: NSExceptionName("test"), reason: "test", userInfo: nil).raise()
    }

    @IBAction func onClickSimpleMessage() {
        // Send a simple message
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", message: "Some message", level: .Info, data: ["hehe": "hoho"]))
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", to: "point b", from: "point a"))
        SentryClient.shared?.captureMessage("Hehehe, this is totes not useful", level: .Error)
    }
    
    @IBAction func onClickComplexMessage() {
        // Send a customly built event
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test", url: "www.hammockdesk.com", method: "GET"))
        let event = Event.build("Another example 4") {
            $0.level = .Fatal
            $0.tags = ["status": "test"]
            $0.extra = [
                "name": "Josh Holtz",
                "favorite_power_ranger": "green/white"
            ]
        }
        SentryClient.shared?.captureEvent(event)
    }
}
