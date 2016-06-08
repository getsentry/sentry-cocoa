//
//  CrashHandler.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/13/16.
//
//

import Foundation

internal typealias GeneratedEvent = (event: Event) -> ()

internal protocol CrashHandler: EventProperties {
	var breadcrumbsSerialized: BreadcrumbStore.SerializedType? { get set }
	func startCrashReporting(generatedEvent: GeneratedEvent)
}
