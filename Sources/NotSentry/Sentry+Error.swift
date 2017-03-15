//
//  Sentry+Error.swift
//  Sentry
//
//  Created by Lukas Stabe on 22.05.16.
//
//

import Foundation

internal enum SentryError: Error {
    case InvalidDSN
    case InvalidCrashReport
}

extension Event {
    // broken out into a separate function for testability
    internal convenience init(error: NSError, frame: Frame) {
        let message = "\(error.domain).\(error.code) in \(frame.culprit)"
        
        self.init(message, level: .Error)
        stacktrace = Stacktrace(frames: [frame])
        culprit = frame.culprit
        
        if let cleanedUserValue = sanitize(error.userInfo) as? [String: AnyType] {
            extra = ["user_info": cleanedUserValue]
        } else {
            Log.Error.log("Failed to capture errors userInfo, since it contained non-string keys: \(error)")
        }
        
        exceptions = [Exception(value: "\(error.domain) (\(error.code))", type: error.domain)]
    }
}

extension SentryClient {
    public func captureError(error: NSError, file: String = #file, line: Int = #line, function: String = #function) {
        let frame = Frame(fileName: file, function: function, module: nil, line: line)
        let event = Event(error: error, frame: frame)
        captureEvent(event)
    }
}
