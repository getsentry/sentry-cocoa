//
//  NSDate+Extras.swift
//  SentrySwift
//
//  Created by David Chavez on 25/05/16.
//
//

import Foundation

// MARK: - NSDate

private let dateFormatter: NSDateFormatter  = {
    let df = NSDateFormatter()
    df.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    df.timeZone = NSTimeZone(abbreviation: "UTC")
    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return df
}()

extension NSDate {
    internal static func fromISO8601(iso8601String: String) -> NSDate? {
        return dateFormatter.dateFromString(iso8601String)
    }
    
    internal var iso8601: String {
        return dateFormatter.stringFromDate(self)
    }
}
