//
//  SentryTestTransport.swift
//  SentryTests
//
//  Created by Philipp Hofmann on 08.04.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

import Foundation

@objc
public class SentryTestTransport: NSObject, SentryTransport {
    public func send(event: Event, completion completionHandler: SentryRequestFinished? = nil) {
        
    }
    
    public func send(envelope: SentryEnvelope, completion completionHandler: SentryRequestFinished? = nil) {
        
    }
    
    public func sendAllStoredEvents() {
        
    }
    
    
}
