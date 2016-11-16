//
//  Request.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/7/16.
//
//

import Foundation

extension SentryClient {
	
	/*
	Sends given event to the API
	- Parameter event: An event
	- Parameter finished: A closure with the success status
	*/
	internal func sendEvent(_ event: Event, finished: SentryEndpointRequestFinished? = nil) {
        #if swift(>=3.0)
            SentryEndpoint.store(event: event).send(dsn: dsn, finished: finished)
        #else
            SentryEndpoint.store(event: event).send(dsn, finished: finished)
        #endif
	}
    
    /*
     Sends given event to the API
     - Parameter event: An event
     - Parameter finished: A closure with the success status
     */
    internal func sendEvent(_ event: SavedEvent, finished: SentryEndpointRequestFinished? = nil) {
        #if swift(>=3.0)
            SentryEndpoint.storeSavedEvent(event: event).send(dsn: dsn, finished: finished)
        #else
            SentryEndpoint.storeSavedEvent(event: event).send(dsn, finished: finished)
        #endif
    }
	  
    func sendUserFeedback() {
        let userFeedback = UserFeedback()
        userFeedback.name = "Daniel G."
        userFeedback.email = "daniel.griesser.86@gmail.com"
        userFeedback.comments = "User Feedback is working 🚀"
        #if swift(>=3.0)
            SentryEndpoint.userFeedback(userFeedback: userFeedback).send(dsn: dsn, finished: nil)
        #else
            SentryEndpoint.userFeedback(userFeedback: userFeedback).send(dsn, finished: nil)
        #endif
    }
}
