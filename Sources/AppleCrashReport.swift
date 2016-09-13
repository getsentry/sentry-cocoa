//
//  AppleCrashReport.swift
//  SentrySwift
//
//  Created by Josh Holtz on 2/17/16.
//
//

import Foundation

/// A class used to represent the Apple crash report attached to an event
@objc public class AppleCrashReport: NSObject {

	// MARK: - Attributes

	public var crash: [String: Any]
	public var binaryImages: [[String: Any]]
	public var system: [String: Any]
	
	/*
	Creates an apple crash report
	- Parameter crash: A dictionary of crash info
	- Parameter binaryImages: An array of dictionaries of binary images
	- Parameter system: A dictionary of system info for the crash
	*/
	public init(crash: [String: Any], binaryImages: [[String: Any]], system: [String: Any]) {
		self.crash = crash
		self.binaryImages = binaryImages
		self.system = system

		super.init()
	}
}

extension AppleCrashReport: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [
			"crash": crash,
			"binary_images": binaryImages,
			"system": system
		]
	}
}
