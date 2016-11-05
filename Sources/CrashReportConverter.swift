//
//  CrashReportConverter.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 05/11/16.
//
//

import Foundation

public class CrashReportConverter {
    
    internal func mapReportToEvent(_ report: CrashDictionary) -> Event? {
        
        // Extract crash timestamp
        #if swift(>=3.0)
            let timestamp: NSDate = {
                var date: Date?
                if let reportDict = report["report"] as? CrashDictionary, let timestampStr = reportDict["timestamp"] as? String {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    date = dateFormatter.date(from: timestampStr)
                }
                return date as NSDate? ?? NSDate()
            }()
        #else
            let timestamp: NSDate = {
            var date: NSDate?
            if let timestampStr = report["report"]?["timestamp"] as? String {
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
            dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
            date = dateFormatter.dateFromString(timestampStr)
            }
            return date ?? NSDate()
            }()
        #endif
        
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
        
        let diagnosis = crashDict["diagnosis"] as? String
        
        guard let errorDict = crashDict["error"] as? [String: AnyObject] else {
            SentryLog.Error.log("Could not make a valid exception stacktrace from crash report: \(report)")
            return nil
        }
        
        guard let threadDicts = crashDict["threads"] as? [[String: AnyObject]] else {
            SentryLog.Error.log("Could not make a valid exception stacktrace from crash report: \(report)")
            return nil
        }
        
        let binaryImages = binaryImagesDicts.flatMap({BinaryImage(appleCrashBinaryImagesDict: $0)})
        
        let debugMeta = DebugMeta(binaryImages: binaryImages)
        
        let threads = threadDicts.flatMap({Thread(appleCrashThreadDict: $0, binaryImages: binaryImages)})
        guard let exception = Exception(appleCrashErrorDict: errorDict, threads: threads, diagnosis: diagnosis) else {
            SentryLog.Error.log("Could not make a valid exception stacktrace from crash report: \(report)")
            return nil
        }
        
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
    
    private func parseUserInfo(_ userInfo: CrashDictionary?) -> (tags: EventTags?, extra: EventExtra?, user: User?, breadcrumbsSerialized: BreadcrumbStore.SerializedType?, releaseVersion:String?) {
        return (
            userInfo?[keyEventTags] as? EventTags,
            userInfo?[keyEventExtra] as? EventExtra,
            User(dictionary: userInfo?[keyUser] as? [String: AnyObject]),
            userInfo?[keyBreadcrumbsSerialized] as? BreadcrumbStore.SerializedType,
            userInfo?[keyReleaseVersion] as? String
        )
    }
    
}
