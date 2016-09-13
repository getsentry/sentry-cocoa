//
//  NSDate+Extras.swift
//  SentrySwift
//
//  Created by David Chavez on 25/05/16.
//
//

import Foundation

// MARK: - NSDate

private let dateFormatter: DateFormatter  = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(abbreviation: "UTC")
    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return df
}()

extension Date {
    internal static func fromISO8601(iso8601String: String) -> Date? {
        return dateFormatter.date(from: iso8601String)
    }
    
    internal var iso8601: String {
        return dateFormatter.string(from: self)
    }
}
