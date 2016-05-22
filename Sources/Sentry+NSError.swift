//
//  Sentry+NSError.swift
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
        return nil
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

    public func captureError(error: NSError, function: String = #function, file: String = #file, line: Int = #line) {
        let culprit = "\((file as NSString).lastPathComponent):\(line) \(function)"
        let message = "\(error.domain).\(error.code) in \(culprit)"

        let event = Event.build(message) {
            $0.level = .Error
            $0.culprit = culprit
            $0.extra = ["user_info": cleanValue(error.userInfo as! [String: AnyObject])!]
        }

        captureEvent(event)
    }
}
