//
//  EventOffline.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/25/16.
//
//

import Foundation

private let directoryNamePrefix = "sentry-swift-"

internal typealias SavedEvent = (data: Data, deleteEvent: () -> ())

extension SentryClient {
    
    /// Saves given event to disk
    internal func saveEvent(_ event: Event) {
        do {
            // Gets write path and serialized string for event
            guard let path = try writePath(event), let text = try serializedString(event) else { return }
            
            // Writes the event data to file
            #if swift(>=3.0)
                try text.write(toFile: path, atomically: false, encoding: String.Encoding.utf8)
            #else
                try text.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
            #endif
            SentryLog.Debug.log("Saved event \(event.eventID) to \(path)")
        } catch {
            SentryLog.Error.log("Failed to save event \(event.eventID): \(error)")
        }
    }
    
    /// Fetches events that were saved to disk.
    internal func savedEvents(since now: TimeInterval = Date().timeIntervalSince1970) -> [SavedEvent] {
        do {
            guard let path = directory() else { return [] }
            
            #if swift(>=3.0)
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
                                SentryLog.Debug.log("Deleted event at path - \(absolutePath)")
                            } catch {
                                SentryLog.Error.log("Failed to delete event at path - \(absolutePath)")
                            }
                        })
                }
            #else
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
                                SentryLog.Debug.log("Deleted event at path - \(absolutePath)")
                            } catch {
                                SentryLog.Error.log("Failed to delete event at path - \(absolutePath)")
                            }
                        })
                }
            #endif
        } catch let error as NSError {
            SentryLog.Debug.log(error.localizedDescription)
        }
        return []
    }
    
    // MARK: - Private Helpers
    
    /// Path of directory to which events will be saved in offline mode
    private func directory() -> String? {
        #if swift(>=3.0)
            guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return nil }
        #else
            guard let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first else { return nil }
        #endif
        
        guard let serverURLString = dsn.url.absoluteString else {
            return nil
        }
        
        let directory = "\(directoryNamePrefix)\(serverURLString.hashValue)"
        
        #if swift(>=3.0)
            return (documentsPath as NSString).appendingPathComponent(directory)
        #else
            return (documentsPath as NSString).stringByAppendingPathComponent(directory)
        #endif
    }
    
    /*
     Creates directory to save events into in offline mode
     - Parameter event: The event which we'll be trying to save
     - Throws: Will throw upon failure to create directory
     - Returns: Unique path to which save the given event
     */
    private func writePath(_ event: Event) throws -> String? {
        guard let sentryDir = directory() else { return nil }
        let date = NSDate().timeIntervalSince1970 + 60 + Double(arc4random_uniform(10) + 1)
        
        #if swift(>=3.0)
            try FileManager.default.createDirectory(atPath: sentryDir, withIntermediateDirectories: true, attributes: nil)
            return (sentryDir as NSString).appendingPathComponent("\(date)-\(event.eventID)")
        #else
            try NSFileManager.defaultManager().createDirectoryAtPath(sentryDir, withIntermediateDirectories: true, attributes: nil)
            return (sentryDir as NSString).stringByAppendingPathComponent("\(date)-\(event.eventID)")
        #endif
    }
    
    /*
     Serializes an event into a `String` we can write to disk
     - Parameter event: Event we want to serialize
     - Throws: Will throw upon failure to serializing to JSON
     - Returns: Serialized string
     */
    private func serializedString(_ event: Event) throws -> String? {
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
