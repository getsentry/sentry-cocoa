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
    case none, error, debug, verbose
    
    public var description: String {
        switch self {
        case .none:
            return ""
        case .error:
            return "Error"
        case .debug:
            return "Debug"
        case .verbose:
            return "Verbose"
        }
    }
    
    internal func log(_ message: String) {
        guard rawValue <= SentryClient.logLevel.rawValue else { return }
        print("Sentry - \(description):: \(message)")
    }
}
