//
//  CrashReportConverter.swift
//  Sentry
//
//  Created by Daniel Griesser on 05/11/16.
//
//

import Foundation

internal final class CrashReportConverter {
    
    typealias UserInfo = (tags: EventTags?,
        extra: EventExtra?,
        user: User?,
        breadcrumbsSerialized: BreadcrumbStore.SerializedType?,
        releaseVersion: String?,
        buildNumber: String?)
    
    private static func checkIncompleteReport(_ report: CrashDictionary) -> CrashDictionary {
        if let reCrash = report["recrash_report"] as? CrashDictionary {
            Log.Debug.log("Found incomplete crash, falling back to recrash_report - Possible not showing all thread information")
            return reCrash
        }
        return report
    }
    
    internal static func convertReportToEvent(_ report: CrashDictionary) -> Event? {
        Log.Verbose.log("KSCrash Report = \(report)")
        
        var crashReport = checkIncompleteReport(report)
        
        // Extract crash timestamp
        let timestamp: NSDate = {
            var date: NSDate?
            if let reportDict = crashReport["report"] as? CrashDictionary, let timestampStr = reportDict["timestamp"] as? String {
                date = NSDate.fromISO8601(timestampStr)
            }
            return date as NSDate? ?? NSDate()
        }()
        
        // Populate user info
        let userInfo = parseUserInfo(crashReport["user"] as? CrashDictionary)
        
        // Generating threads, exceptions, and debug meta for crash report
        guard let binaryImagesDicts = crashReport["binary_images"] as? [[String: AnyObject]] else {
            Log.Error.log("missing 'binary_images' in crash report: \(crashReport)")
            return nil
        }
        
        guard let crashDict = crashReport["crash"] as? [String: AnyObject] else {
            Log.Error.log("missing 'crash' in crash report: \(crashReport)")
            return nil
        }
        
        guard let errorDict = crashDict["error"] as? [String: AnyObject] else {
            Log.Error.log("missing 'error' in crash report: \(crashReport)")
            return nil
        }
        
        guard let threadDicts = crashDict["threads"] as? [[String: AnyObject]] else {
            Log.Error.log("missing 'threads' in crash report: \(crashReport)")
            return nil
        }
        
        let binaryImages = binaryImagesDicts.flatMap({ BinaryImage(appleCrashBinaryImagesDict: $0) })
        let debugMeta = DebugMeta(binaryImages: binaryImages)
        var threads = threadDicts.flatMap({ Thread(appleCrashThreadDict: $0, binaryImages: binaryImages) })
        
        let exception = Exception(appleCrashErrorDict: errorDict, userInfo: userInfo)
        exception.update(threads: &threads) // the order is important for this 2 calls
        exception.update(ksCrashDiagnosis: crashDict["diagnosis"] as? String) // the order is important for this 2 calls
        
        /// Generate event to sent up to API
        /// Sends a blank message because server does stuff
        let event = Event.build("") {
            $0.level = .Fatal
            $0.timestamp = timestamp
            $0.tags = userInfo.tags ?? [:]
            $0.extra = (sanitize(userInfo.extra ?? [:]) as? [String: AnyType]) ?? [:]
            $0.user = userInfo.user
            $0.breadcrumbsSerialized = userInfo.breadcrumbsSerialized
            $0.releaseVersion = userInfo.releaseVersion
            $0.buildNumber = userInfo.buildNumber
            
            $0.threads = threads
            $0.exceptions = [exception].flatMap({ $0 })
            $0.debugMeta = debugMeta
        }
        
        return event
    }
    
    private static func parseUserInfo(_ userInfo: CrashDictionary?) -> UserInfo {
        return (
            userInfo?[keyEventTags] as? EventTags,
            sanitize(userInfo?[keyEventExtra] ?? [:]) as? EventExtra,
            User(dictionary: userInfo?[keyUser] as? [String: AnyObject]),
            userInfo?[keyBreadcrumbsSerialized] as? BreadcrumbStore.SerializedType,
            userInfo?[keyReleaseVersion] as? String,
            userInfo?[keyBuildNumber] as? String
        )
    }
    
}
