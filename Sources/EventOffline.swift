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

	/// Saves an event to disk
	/// - Parameter event: An event
	public func saveEvent(event: Event) {
		
		do {
			// Gets write path and serialized string for event
			guard let path = try writePath(event), text = try serializedString(event) else {
				return
			}
			
			// Writes the event data to file
			try text.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
			SentryLog.Debug.log("Saved event \(event.eventID) to \(path)")
		} catch let error as NSError {
			SentryLog.Error.log("Failed to save event \(event.eventID): \(error)")
		}
	}
	
	public typealias SavedEvent = (data: NSData, deleteEvent: () -> ())
	
	/// Gets an array of saved events that are on disk.
	/// The closure to delete file should be used after
	/// the event is sent to the API.
	/// - Returns: [SavedEvent]
	public func savedEvents() -> [SavedEvent] {
	
		// Flat maps over the file paths in the directory
		// and generates a tuple with the data and a closure
		// to delete the file
		//
		// The closure to delete file should be used after
		// the event is sent to the API
		do {
			guard let path = directory() else { return [] }
			
			return try NSFileManager.defaultManager()
				.contentsOfDirectoryAtPath(path as String)
				.flatMap { fileName in
					let absolutePath = path.stringByAppendingPathComponent(fileName)
					guard let data = NSData(contentsOfFile: absolutePath) else {
						return nil
					}
					
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
	
	// MARK: Private
	
	/// Gets the directory in which events will be saved for offline use (crashes)
	/// - Returns: NSString
	private func directory() -> NSString? {
		/// Gets documents directory
		guard let documentsDir: NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first else {
			return nil
		}
		
		// Appends a hash of the server url onto the documents directory path
		// This will give each client a separate directory
		let directory = "\(directoryNamePrefix)\(dsn.serverURL.absoluteString.hashValue)"
		return documentsDir.stringByAppendingPathComponent(directory)
	}
	
	/// Generates a path to write to based on `directory()` using the event's `eventID` as the file name
	/// - Throws: Can throw while trying to create directory at path
	/// - Returns: String?
	private func writePath(event: Event) throws -> String? {
		guard let sentryDir = directory() else { return nil }
		
		try NSFileManager.defaultManager().createDirectoryAtPath(sentryDir as String, withIntermediateDirectories: true, attributes: nil)
		return sentryDir.stringByAppendingPathComponent(event.eventID);
	}
	
	/// Serializes an event into a string for writing to disk
	/// - Throws: Can throw while serializing JSON
	/// - Returns: String?
	private func serializedString(event: Event) throws -> String? {
		let data = try NSJSONSerialization.dataWithJSONObject(event.serialized, options: [])
		return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
	}
}
