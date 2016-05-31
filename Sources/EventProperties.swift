//
//  EventProperties.swift
//  SentrySwift
//
//  Created by Josh Holtz on 2/1/16.
//
//

import Foundation

/// Protocol defining common editable properties of Sentry client and Event
internal protocol EventProperties {

	// MARK: - Attributes
	var tags: EventTags? { get set }
	var extra: EventExtra? { get set }
	
	// MARK: - Interfaces
	var user: User? { get set }
}

extension EventProperties {

    /*
    Merges another EventProperties into this. Will only replace non-existing keys.
    - Parameter from: EventProperties to merge
    */
    internal mutating func mergeProperties(from other: EventProperties) {
		// Cannot merge on nil dictionaries
		tags = tags ?? [:]
		extra = extra ?? [:]
		
        tags?.unionInPlace(other.tags ?? [:])
        extra?.unionInPlace(other.extra ?? [:])
        user = user ?? other.user
    }
}
