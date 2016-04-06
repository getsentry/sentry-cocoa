//
//  AppleCrashReport.swift
//  SentrySwift
//
//  Created by Josh Holtz on 2/17/16.
//
//

import Foundation

/// A class used to represent the apple crash report attached to an event
@objc public class AppleCrashReport: NSObject {
	public var crash: [String: AnyObject]
	public var binaryImages: [[String: AnyObject]]
	public var system: [String: AnyObject]
	
	/// Creates an apple crash report
	/// - Parameter crash: A dictionary of crash info
	/// - Parameter binaryImages: An array of dictionaries of binary images
	/// - Parameter system: A dictionary of system info for the crash
	public init(crash: [String: AnyObject], binaryImages: [[String: AnyObject]], system: [String: AnyObject]) {
		self.crash = crash
		self.binaryImages = binaryImages
		self.system = system
	}
}

extension AppleCrashReport: EventSerializable {
	public typealias SerializedType = SerializedTypeDictionary
	public var serialized: SerializedType {
		return [
			"crash": crash,
			"binary_images": binaryImages,
			"system": system
		]
	}
	
}