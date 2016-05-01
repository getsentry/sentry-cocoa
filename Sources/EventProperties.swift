//
//  EventProperties.swift
//  SentrySwift
//
//  Created by Josh Holtz on 2/1/16.
//
//

import Foundation

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
	
	/// Merges event properties (and potentially overwrite with) into event.
	/// - Parameter eventProperties: Event properties to merge on self
	/// - Returns: Self
	public func mergeProperties(eventProperties: EventProperties) -> Self {
		tags = merge(eventProperties.tags, onTo: tags)
		extra = merge(eventProperties.extra, onTo: extra)
		
		// Only override user if we have one to override
		if let userToSet = eventProperties.user {
			user = userToSet
		}
		
		return self
	}
	
	/// Merges event tags together.
	/// - Parameter eventTags: Tags to merge into (and potentiall overwrite with)
	/// - Parameter onToEventTags: Tags to merge on
	/// - Returns: Self
	public func merge(eventTags: EventTags?, onTo onToEventTags: EventTags?) -> EventTags {
		var base = onToEventTags ?? EventTags()
		let takeFrom = eventTags ?? EventTags()
		
		for (k, v) in takeFrom {
			base.updateValue(v, forKey: k)
		}
		
		return base
	}
	
	/// Merges event extra together.
	/// - Parameter eventExtra: Extra to merge into (and potentiall overwrite with)
	/// - Parameter onToEventExtra: Extra to merge on
	/// - Returns: Self
	public func merge(eventExtra: EventExtra?, onTo onToEventExtra: EventExtra?) -> EventExtra {
		var base = onToEventExtra ?? EventExtra()
		let takeFrom = eventExtra ?? EventExtra()
		
		for (k, v) in takeFrom {
			base.updateValue(v, forKey: k)
		}
		
		return base
	}
}
