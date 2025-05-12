//
//  FrameTracker.swift
//  Sentry
//
//  Created by Noah Martin on 5/9/25.
//  Copyright © 2025 Sentry. All rights reserved.
//

import Foundation

@objc
class FrameTracker: NSObject {
    
    let observer: CFRunLoopObserver
    
    @objc
    override init() {
        observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.allActivities.rawValue, true, .min) { _, activity in
            let mode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain())!
            switch activity {
            // case .entry, .beforeTimers, .afterWaiting, .beforeSources:
                // self.startTime = CAMedia
            case .entry:
                print("entry \(mode)")
            case .beforeTimers:
                print("before timers \(mode)")
            case .afterWaiting:
                print("after waiting \(mode)")
            case .beforeSources:
                print("before sources \(mode)")
            case .beforeWaiting:
                print("before waiting \(mode)")
            case .exit:
                print("exit \(mode)")
            default:
                print(activity)
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
    }
}
