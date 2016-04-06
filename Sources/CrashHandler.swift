//
//  CrashHandler.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/13/16.
//
//

import Foundation

@objc public protocol CrashHandler: EventProperties {
	var breadcrumbsSerialized: BreadcrumbStore.SerializedType? { get set }
	func startCrashReporting(createdEvent: (event: Event) -> ())
}