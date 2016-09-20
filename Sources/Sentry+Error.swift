//
//  Sentry+Error.swift
//  SentrySwift
//
//  Created by Lukas Stabe on 22.05.16.
//
//

import Foundation


private func cleanValue(_ v: AnyType) -> AnyType? {
    switch v {
    case is NSNumber: fallthrough
    case is NSString: fallthrough
    case is NSNull:
        return v

    case let v as [String: AnyType]:
        return cleanDict(v)

    case let v as [AnyType]:
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

private func cleanDict(_ d: [String: AnyType]) -> [String: AnyType] {
    var ret = [String: AnyType]()

    for (k, v) in d {
        guard let c = cleanValue(v) else { continue }
        ret[k] = c
    }

    return ret
}

extension Event {

    // broken out into a separate function for testability
    internal convenience init(error: NSError, frame: Frame) {
        let message = "\(error.domain).\(error.code) in \(frame.culprit)"

        self.init(message, level: .Error)
        stacktrace = Stacktrace(frames: [frame])
		culprit = frame.culprit

        if let cleanedUserInfo = cleanValue(error.userInfo) as? [String: AnyType] {
            extra = ["user_info": cleanedUserInfo]
        } else {
            SentryLog.Error.log("Failed to capture errors userInfo, since it contained non-string keys: \(error)")
        }

        exceptions = [Exception(value: "\(error.domain) (\(error.code))", type: error.domain)]
    }
}

extension SentryClient {
    public func captureError(error: NSError, file: String = #file, line: Int = #line, function: String = #function) {
		let frame = Frame(file: file, function: function, module: nil, line: line)
		let event = Event(error: error, frame: frame)
        captureEvent(event)
    }
}
