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

	public typealias SavedEvent = (data: Data, deleteEvent: () -> ())

	/// Saves given event to disk
	public func saveEvent(event: Event) {
		do {
			// Gets write path and serialized string for event
			guard let path = try writePath(event: event), let text = try serializedString(event: event) else { return }
			
			// Writes the event data to file
			try text.write(toFile: path, atomically: false, encoding: String.Encoding.utf8)
			SentryLog.Debug.log(message: "Saved event \(event.eventID) to \(path)")
		} catch {
			SentryLog.Error.log(message: "Failed to save event \(event.eventID): \(error)")
		}
	}

	/// Fetches events that were saved to disk. **Make sure to delete after use**
	public func savedEvents() -> [SavedEvent] {
		do {
			guard let path = directory() else { return [] }
			
			return try FileManager.default
				.contentsOfDirectory(atPath: path)
				.flatMap { fileName in
					let absolutePath = path+"/"+fileName
                    var data: Data!
                    do {
                        data = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
                    } catch _ {
                        return nil
                    }
					
					return (data, {
						do {
							try FileManager.default.removeItem(atPath: absolutePath)
							SentryLog.Debug.log(message: "Deleted event at path - \(absolutePath)")
						} catch {
							SentryLog.Error.log(message: "Failed to delete event at path - \(absolutePath)")
						}
					})
				}
		} catch let error as NSError {
			// Debug logging this error since its purely informational
			// This folder doesn't need to exist
			SentryLog.Debug.log(message: error.localizedDescription)
		}
		
		return []
	}


	// MARK: - Private Helpers
	
	/// Path of directory to which events will be saved in offline mode
	private func directory() -> String? {
		guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return nil }

        let serverURLString: String! = dsn.serverURL.absoluteString
        if serverURLString == nil { return nil }

        let directory = "\(directoryNamePrefix)\(serverURLString.hashValue)"

        return (documentsPath as NSString).appendingPathComponent(directory)
	}
	
	/*
	Creates directory to save events into in offline mode
	- Parameter event: The event which we'll be trying to save
	- Throws: Will throw upon failure to create directory
	- Returns: Unique path to which save the given event
	*/
	private func writePath(event: Event) throws -> String? {
		guard let sentryDir = directory() else { return nil }

		try FileManager.default.createDirectory(atPath: sentryDir, withIntermediateDirectories: true, attributes: nil)
		return (sentryDir as NSString).appendingPathComponent(event.eventID)
	}
	
	/*
	Serializes an event into a `String` we can write to disk
	- Parameter event: Event we want to serialize
	- Throws: Will throw upon failure to serializing to JSON
	- Returns: Serialized string
	*/
	private func serializedString(event: Event) throws -> String? {
		if JSONSerialization.isValidJSONObject(event.serialized) {
			let data = try JSONSerialization.data(withJSONObject: event.serialized, options: [])
			return String(data: data, encoding: String.Encoding.utf8)
		}

		return nil
	}
}
