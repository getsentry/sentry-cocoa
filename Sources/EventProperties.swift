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
	var releaseVersion: String? { get set }
	var tags: EventTags { get set }
	var extra: EventExtra { get set }
	
	// MARK: - Interfaces
	var user: User? { get set }
}
