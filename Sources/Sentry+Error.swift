//
//  Sentry+Error.swift
//  SentrySwift
//
//  Created by Lukas Stabe on 22.05.16.
//
//

import Foundation


private func cleanValue(v: Any) -> Any? {
    switch v {
    case is NSNumber: fallthrough
    case is NSString: fallthrough
    case is NSNull:
        return v

    case let v as [String: Any]:
        return cleanDict(d: v)

    case let v as [Any]:
        return v.flatMap(cleanValue)

    case let v as NSURL:
        return v.absoluteString

    case let v as NSError:
        return ["domain": v.domain, "code": v.code, "user_info": cleanValue(v: v.userInfo)!]
    default:
        return "\(v)"
    }
}

private func cleanDict(d: [String: Any]) -> [String: Any] {
    var ret = [String: Any]()

    for (k, v) in d {
        guard let c = cleanValue(v: v) else { continue }
        ret[k] = c
    }

    return ret
}

extension Event {

    // broken out into a separate function for testability
    internal convenience init(error: NSError, frame: Frame) {
        let message = "\(error.domain).\(error.code) in \(frame.culprit)"

        self.init(message, level: .error)
        stacktrace = Stacktrace(frames: [frame])
		culprit = frame.culprit

        if let cleanedUserInfo = cleanValue(v: error.userInfo) as? [String: Any] {
            extra = ["user_info": cleanedUserInfo]
        } else {
            SentryLog.Error.log(message: "Failed to capture errors userInfo, since it contained non-string keys: \(error)")
        }

        exception = [Exception(type: error.domain, value: "\(error.domain) (\(error.code))")]
    }
}

extension SentryClient {
    public func captureError(error: NSError, file: String = #file, line: Int = #line, function: String = #function) {
		let frame = Frame(file: file, function: function, module: nil, line: line)
		let event = Event(error: error, frame: frame)
        captureEvent(event: event)
    }
}
