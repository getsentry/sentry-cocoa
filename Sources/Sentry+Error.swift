//
//  Sentry+Error.swift
//  SentrySwift
//
//  Created by Lukas Stabe on 22.05.16.
//
//

import Foundation


private func cleanValue(v: AnyObject) -> AnyObject? {
    switch v {
    case is NSNumber: fallthrough
    case is NSString: fallthrough
    case is NSNull:
        return v

    case let v as [String: AnyObject]:
        return cleanDict(v)

    case let v as [AnyObject]:
        return v.flatMap(cleanValue)

    case let v as NSURL:
        return v.absoluteString

    case let v as NSError:
        return [
            "domain": v.domain,
            "code": v.code,
            "user_info": cleanValue(v.userInfo)!
        ]

    default:
        return "\(v)"
    }
}

private func cleanDict(d: [String: AnyObject]) -> [String: AnyObject] {
    var ret = [String: AnyObject]()

    for (k, v) in d {
        guard let c = cleanValue(v) else { continue }
        ret[k] = c
    }

    return ret
}

extension SentryClient {

    // broken out into a separate function for testability
    func eventFor(error error: NSError, location: SourceLocation) -> Event {
        let message = "\(error.domain).\(error.code) in \(location.culprit)"

        let event = Event(message, level: .Error)
        event.mergeSourceLocation(location)

        if let cleanedUserInfo = cleanValue(error.userInfo) as? [String: AnyObject] {
            event.extra = ["user_info": cleanedUserInfo]
        } else {
            SentryLog.Error.log("Failed to capture errors userInfo, since it contained non-string keys: \(error)")
        }

        return event
    }

    public func captureError(error: NSError, file: String = #file, line: Int = #line, function: String = #function) {
        let loc = SourceLocation(file: file, line: line, function: function)
        let event = eventFor(error: error, location: loc)
        captureEvent(event)
    }
}
