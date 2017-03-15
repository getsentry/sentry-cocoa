//
//  EventOffline.swift
//  Sentry
//
//  Created by Josh Holtz on 1/25/16.
//
//

import Foundation

private let directoryNamePrefix = "sentry-swift-"

internal typealias SavedEvent = (data: Data, deleteEvent: () -> Void)

extension SentryClient {
    
    /// Saves given event to disk
    internal func saveEvent(_ event: Event) {
        do {
            // Gets write path and serialized string for event
            guard let path = try writeEvent(event, to: appendSentryDirToPath(cachesDirectory())),
                let text = try serializeEvent(event) else {
                    return
            }
            
            // Writes the event data to file
            #if swift(>=3.0)
                try text.write(toFile: path, atomically: false, encoding: String.Encoding.utf8)
            #else
                try text.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
            #endif
            Log.Debug.log("Saved event \(event.eventID) to \(path)")
        } catch {
            Log.Error.log("Failed to save event \(event.eventID): \(error)")
        }
    }
    
    /// Fetches events that were saved to disk.
    internal func savedEvents(since now: TimeInterval = Date().timeIntervalSince1970) -> [SavedEvent] {
        guard let cachesPath = appendSentryDirToPath(cachesDirectory()) else { return [] }
        guard let documentsPath = appendSentryDirToPath(documentDirectory()) else { return [] }
        
        let cachedEvents = loadSavedEventsFromPath(cachesPath, since: now)
        deleteEmptyFolderAtPath(cachesPath)
        let documentsEvents = loadSavedEventsFromPath(documentsPath, since: now)
        deleteEmptyFolderAtPath(documentsPath)
        
        return cachedEvents + documentsEvents
    }
    
    // swiftlint:disable function_body_length
    // MARK: - Private Helpers
    private func loadSavedEventsFromPath(_ path: String, since now: TimeInterval) -> [SavedEvent] {
        do {
            #if swift(>=3.0)
                guard FileManager.default.fileExists(atPath: path) else {
                    return []
                }
                return try FileManager.default
                    .contentsOfDirectory(atPath: path)
                    .filter { fileName in
                        let splitName = fileName.characters.split { $0 == "-" }.map(String.init)
                        guard let storedTime = Double(splitName[0]) else {
                            return true
                        }
                        return now > storedTime
                    }
                    .flatMap { fileName in
                        let absolutePath: String = (path as NSString).appendingPathComponent(fileName)
                        guard let data = NSData(contentsOfFile: absolutePath) else { return nil }
                        
                        return (data as Data, {
                            do {
                                try FileManager.default.removeItem(atPath: absolutePath)
                                Log.Debug.log("Deleted event at path - \(absolutePath)")
                            } catch {
                                Log.Error.log("Failed to delete event at path - \(absolutePath)")
                            }
                        })
                    }
            #else
                guard NSFileManager.defaultManager().fileExistsAtPath(path) else {
                    return []
                }
                return try NSFileManager.defaultManager()
                    .contentsOfDirectoryAtPath(path)
                    .filter { fileName in
                        let splitName = fileName.characters.split { $0 == "-" }.map(String.init)
                        guard let storedTime = Double(splitName[0]) else {
                            return true
                        }
                        return now > storedTime
                    }
                    .flatMap { fileName in
                        let absolutePath: String = (path as NSString).stringByAppendingPathComponent(fileName)
                        guard let data = NSData(contentsOfFile: absolutePath) else { return nil }
                        
                        return (data, {
                            do {
                                try NSFileManager.defaultManager().removeItemAtPath(absolutePath)
                                Log.Debug.log("Deleted event at path - \(absolutePath)")
                            } catch {
                                Log.Error.log("Failed to delete event at path - \(absolutePath)")
                            }
                        })
                    }
            #endif
        } catch let error as NSError {
            Log.Error.log(error.localizedDescription)
        }
        return []
    }
    // swiftlint:enable function_body_length
    
    private func deleteEmptyFolderAtPath(_ path: String) {
        do {
            #if swift(>=3.0)
                guard FileManager.default.fileExists(atPath: path) else { return }
                guard try FileManager.default.contentsOfDirectory(atPath: path).isEmpty else { return }
                try FileManager.default.removeItem(atPath: path)
            #else
                guard NSFileManager.defaultManager().fileExistsAtPath(path) else { return }
                guard try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path).isEmpty else { return }
                try NSFileManager.defaultManager().removeItemAtPath(path)
            #endif
        } catch let error as NSError {
            Log.Error.log(error.localizedDescription)
        }
    }
    
    private func appendSentryDirToPath(_ path: String?) -> String? {
        guard let path = path else {
            return nil
        }
        
        #if swift(>=3.0)
            let serverURLString = String(describing: dsn.url)
        #else
            let serverURLString = String(dsn.url)
        #endif
        
        let directory = "\(directoryNamePrefix)\(serverURLString.hashValue)"
        
        #if swift(>=3.0)
            return (path as NSString).appendingPathComponent(directory)
        #else
            return (path as NSString).stringByAppendingPathComponent(directory)
        #endif
    }
    
    private func documentDirectory() -> String? {
        #if swift(>=3.0)
            guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return nil }
        #else
            guard let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first else { return nil }
        #endif
        return path
    }
    
    private func cachesDirectory() -> String? {
        #if swift(>=3.0)
            guard let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else { return nil }
        #else
            guard let path = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true).first else { return nil }
        #endif
        return path
    }
    
    /*
     Creates directory to save events into in offline mode
     - Parameter event: The event which we'll be trying to save
     - Throws: Will throw upon failure to create directory
     - Returns: Unique path to which save the given event
     */
    private func writeEvent(_ event: Event, to path: String?) throws -> String? {
        guard let path = path else { return nil }
        let date = Date().timeIntervalSince1970 + 60 + Double(arc4random_uniform(10) + 1)
        
        #if swift(>=3.0)
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return (path as NSString).appendingPathComponent("\(date)-\(event.eventID)")
        #else
            try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
            return (path as NSString).stringByAppendingPathComponent("\(date)-\(event.eventID)")
        #endif
    }
    
    /*
     Serializes an event into a `String` we can write to disk
     - Parameter event: Event we want to serialize
     - Throws: Will throw upon failure to serializing to JSON
     - Returns: Serialized string
     */
    private func serializeEvent(_ event: Event) throws -> String? {
        let serializedEvent = event.serialized
        #if swift(>=3.0)
            if JSONSerialization.isValidJSONObject(serializedEvent) {
                let data = try JSONSerialization.data(withJSONObject: serializedEvent, options: [])
                return String(data: data, encoding: String.Encoding.utf8)
            }
        #else
            if NSJSONSerialization.isValidJSONObject(serializedEvent) {
                let data = try NSJSONSerialization.dataWithJSONObject(serializedEvent, options: [])
                return String(data: data, encoding: NSUTF8StringEncoding)
            }
        #endif
        
        return nil
    }
}
