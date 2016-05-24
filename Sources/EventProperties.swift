//
//  EventProperties.swift
//  SentrySwift
//
//  Created by Josh Holtz on 2/1/16.
//
//

import Foundation

private extension Dictionary {
    mutating func mergeValues(from other: Dictionary<Key, Value>, overrideExisting: Bool = false) {
        for k in other.keys {
            if overrideExisting {
                self[k] = other[k]
            } else {
                self[k] = self[k] ?? other[k]
            }
        }
    }
}

/// Properties that can be set globally on a SentryClient
/// and on an Event.
@objc public protocol EventProperties {
	// Attributes
	var tags: EventTags? { get set }
	var extra: EventExtra? { get set }
	
	// Interfaces
	var user: User? { get set }
}

extension EventProperties {
	/// Merges event properties into self. Only values not set in the receiver are set. Dictionary properties are merged non-recursively, preferring the values in the receiver.
	/// - Parameter eventProperties: Event properties to merge on self
	public func mergeProperties(eventProperties: EventProperties) {
        tags?.mergeValues(from: eventProperties.tags ?? [:])
        extra?.mergeValues(from: eventProperties.extra ?? [:])
        user = user ?? eventProperties.user
	}
}
