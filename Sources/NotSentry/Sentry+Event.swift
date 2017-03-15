//
//  Sentry+Event.swift
//  Sentry
//
//  Created by Daniel Griesser on 07/02/2017.
//
//

import Foundation

extension SentryClient {
    
    /*
     Reports message to Sentry with the given level
     - Parameter message: The message to send to Sentry
     - Parameter level: The severity of the message
     */
    @objc public func captureMessage(_ message: String, level: Severity = .Info) {
        captureEvent(Event(message, level: level))
    }
    
    /// Reports given event to Sentry
    @objc public func captureEvent(_ event: Event) {
        #if swift(>=3.0)
            DispatchQueue(label: SentryClient.queueName).async {
                self.captureEvent(event, useClientProperties: true)
            }
        #else
            dispatch_async(dispatch_queue_create(SentryClient.queueName, nil), {
                self.captureEvent(event, useClientProperties: true)
            })
        #endif
    }
    
    /*
     Reports given event to Sentry
     - Parameter event: An event struct
     - Parameter useClientProperties: Should the client's user, tags and extras also be reported (default is `true`)
     */
    internal func captureEvent(_ event: Event, useClientProperties: Bool, completed: SentryEndpointRequestFinished? = nil) {
        if useClientProperties {
            event.user = event.user ?? user
            event.releaseVersion = event.releaseVersion ?? releaseVersion
            event.buildNumber = event.buildNumber ?? buildNumber
            
            if JSONSerialization.isValidJSONObject(tags) {
                event.tags.unionInPlace(tags)
            }
            
            if JSONSerialization.isValidJSONObject(extra) {
                event.extra.unionInPlace(extra)
            }
            
            if nil == event.breadcrumbsSerialized { // we only want to set the breadcrumbs if there are non in the event
                event.breadcrumbsSerialized = breadcrumbs.serialized
            }
        }
        
        sendEvent(event) { [weak self] success in
            defer { completed?(success) }
            guard !success else {
                #if os(iOS)
                    if event.level == .Fatal {
                        self?.lastSuccessfullySentEvent = event
                    }
                #endif
                return
            }
            self?.saveEvent(event)
        }
        
        // In the end we check if there are any events still stored on disk and send them
        // If the request queue is ready
        if requestManager.isReady {
            sendEventsOnDiskInBackground()
        }
    }
    
    /// Sends events that are stored on disk to the server
    internal func sendEventsOnDiskInBackground() {
        #if swift(>=3.0)
            DispatchQueue(label: SentryClient.queueName).sync {
                self.sendEventsOnDisk()
            }
        #else
            dispatch_sync(dispatch_queue_create(SentryClient.queueName, nil), {
                self.sendEventsOnDisk()
            })
        #endif
    }
    
    /// Attempts to send all events that are saved on disk
    private func sendEventsOnDisk() {
        let events = savedEvents()
        
        for savedEvent in events {
            sendEvent(savedEvent) { success in
                guard success else { return }
                savedEvent.deleteEvent()
            }
        }
    }
}
