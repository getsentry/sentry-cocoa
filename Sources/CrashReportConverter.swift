//
//  CrashReportConverter.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 05/11/16.
//
//

import Foundation

internal final class CrashReportConverter {
    
    internal static func convertReportToEvent(_ report: CrashDictionary) -> Event? {
        // Extract crash timestamp
        let timestamp: NSDate = {
            var date: NSDate?
            if let reportDict = report["report"] as? CrashDictionary, let timestampStr = reportDict["timestamp"] as? String {
                date = NSDate.fromISO8601(timestampStr)
            }
            return date as NSDate? ?? NSDate()
        }()
        
        // Populate user info
        let userInfo = parseUserInfo(report["user"] as? CrashDictionary)
        
        // Generating threads, exceptions, and debug meta for crash report
        guard let binaryImagesDicts = report["binary_images"] as? [[String: AnyObject]] else {
            SentryLog.Error.log("Could not make a valid exception stacktrace from crash report: \(report)")
            return nil
        }
        
        guard let crashDict = report["crash"] as? [String: AnyObject] else {
            SentryLog.Error.log("Could not make a valid exception stacktrace from crash report: \(report)")
            return nil
        }
        
        guard let errorDict = crashDict["error"] as? [String: AnyObject] else {
            SentryLog.Error.log("Could not make a valid exception stacktrace from crash report: \(report)")
            return nil
        }
        
        guard let threadDicts = crashDict["threads"] as? [[String: AnyObject]] else {
            SentryLog.Error.log("Could not make a valid exception stacktrace from crash report: \(report)")
            return nil
        }
        
        let binaryImages = binaryImagesDicts.flatMap({ BinaryImage(appleCrashBinaryImagesDict: $0) })
        
        let debugMeta = DebugMeta(binaryImages: binaryImages)
        
        var threads = threadDicts.flatMap({ Thread(appleCrashThreadDict: $0, binaryImages: binaryImages) })
        
        let exception = Exception(appleCrashErrorDict: errorDict)
        exception.update(threads: &threads) // the order is important for this 2 calls
        exception.update(ksCrashDiagnosis: crashDict["diagnosis"] as? String) // the order is important for this 2 calls
        
        /// Generate event to sent up to API
        /// Sends a blank message because server does stuff
        let event = Event.build("") {
            $0.level = .Fatal
            $0.timestamp = timestamp
            $0.tags = userInfo.tags ?? [:]
            $0.extra = userInfo.extra ?? [:]
            $0.user = userInfo.user
            $0.breadcrumbsSerialized = userInfo.breadcrumbsSerialized
            $0.releaseVersion = userInfo.releaseVersion
            
            $0.threads = threads
            $0.exceptions = [exception].flatMap({$0})
            $0.debugMeta = debugMeta
        }
        
        return event
    }
    
    private static func parseUserInfo(_ userInfo: CrashDictionary?) -> (tags: EventTags?, extra: EventExtra?, user: User?, breadcrumbsSerialized: BreadcrumbStore.SerializedType?, releaseVersion: String?) {
        return (
            userInfo?[keyEventTags] as? EventTags,
            userInfo?[keyEventExtra] as? EventExtra,
            User(dictionary: userInfo?[keyUser] as? [String: AnyObject]),
            userInfo?[keyBreadcrumbsSerialized] as? BreadcrumbStore.SerializedType,
            userInfo?[keyReleaseVersion] as? String
        )
    }
    
}
