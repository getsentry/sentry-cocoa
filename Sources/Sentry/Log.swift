//
//  Log.swift
//  Sentry
//
//  Created by Daniel Griesser on 07/02/2017.
//
//

import Foundation

// This is declared here to keep namespace compatibility with objc
@objc(SentryLog) public enum Log: Int, CustomStringConvertible {
    case None, Error, Debug, Verbose
    
    public var description: String {
        switch self {
        case .None:
            return ""
        case .Error:
            return "Error"
        case .Debug:
            return "Debug"
        case .Verbose:
            return "Verbose"
        }
    }
    
    internal func log(_ message: String) {
        guard rawValue <= SentryClient.logLevel.rawValue else { return }
        print("Sentry - \(description):: \(message)")
    }
}
