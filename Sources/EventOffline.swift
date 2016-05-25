//
//  EventOffline.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/25/16.
//
//

import Foundation

private let directoryNamePrefix = "sentry-swift-"

extension SentryClient {

	public typealias SavedEvent = (data: NSData, deleteEvent: () -> ())

	/// Saves given event to disk
	public func saveEvent(event: Event) {
		do {
			// Gets write path and serialized string for event
			guard let path = try writePath(event), text = try serializedString(event) else { return }
			
			// Writes the event data to file
			try text.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
			SentryLog.Debug.log("Saved event \(event.eventID) to \(path)")
		} catch {
			SentryLog.Error.log("Failed to save event \(event.eventID): \(error)")
		}
	}

	/// Fetches events that were saved to disk. **Make sure to delete after use**
	public func savedEvents() -> [SavedEvent] {
		do {
			guard let path = directory() else { return [] }
			
			return try NSFileManager.defaultManager()
				.contentsOfDirectoryAtPath(path)
				.flatMap { fileName in
					let absolutePath: String = (path as NSString).stringByAppendingPathComponent(fileName)
					guard let data = NSData(contentsOfFile: absolutePath) else { return nil }
					
					return (data, {
						do {
							try NSFileManager.defaultManager().removeItemAtPath(absolutePath)
							SentryLog.Debug.log("Deleted event at path - \(absolutePath)")
						} catch {
							SentryLog.Error.log("Failed to delete event at path - \(absolutePath)")
						}
					})
				}
		} catch let error as NSError {
			SentryLog.Error.log(error.localizedDescription)
		}
		
		return []
	}


	// MARK: - Private Helpers
	
	/// Path of directory to which events will be saved in offline mode
	private func directory() -> String? {
		guard let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first else { return nil }
		let directory: String = "\(directoryNamePrefix)\(dsn.serverURL.absoluteString.hashValue)"
		return (documentsPath as NSString).stringByAppendingPathComponent(directory)
	}
	
	/*
	Creates directory to save events into in offline mode
	- Parameter event: The event which we'll be trying to save
	- Throws: Will throw upon failure to create directory
	- Returns: Unique path to which save the given event
	*/
	private func writePath(event: Event) throws -> String? {
		guard let sentryDir = directory() else { return nil }

		try NSFileManager.defaultManager().createDirectoryAtPath(sentryDir, withIntermediateDirectories: true, attributes: nil)
		return (sentryDir as NSString).stringByAppendingPathComponent(event.eventID)
	}
	
	/*
	Serializes an event into a `String` we can write to disk
	- Parameter event: Event we want to serialize
	- Throws: Will throw upon failure to serializing to JSON
	- Returns: Serialized string
	*/
	private func serializedString(event: Event) throws -> String? {
		let data: NSData = try NSJSONSerialization.dataWithJSONObject(event.serialized, options: [])
		return String(data: data, encoding: NSUTF8StringEncoding)
	}
}
