//
//  NotificationController.swift
//  watchOSCarthage WatchKit Extension
//
//  Created by Josh Holtz on 4/25/17.
//  Copyright © 2017 Sentry. All rights reserved.
//

import WatchKit
import Foundation
import UserNotifications

import Sentry
import KSCrash
import SentryKSCrash

class NotificationController: WKUserNotificationInterfaceController {

    override init() {
		
		let client = SentryClient(dsnString: "example-dsn")
		client?.startCrashHandler()
		
        super.init()
    }
}
