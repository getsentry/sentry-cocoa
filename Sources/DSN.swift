//
//  DSN.swift
//  Sentry
//
//  Created by Josh Holtz on 1/6/16.
//
//

import Foundation

internal typealias XSentryAuthHeader = (key: String, value: String)

/// A class to hold DSN information and populate X-Sentry-Auth header
final class DSN {
    
    internal let url: NSURL
    internal let publicKey: String?
    internal let secretKey: String?
    internal let projectID: String
    
    internal init(url: NSURL, publicKey: String?, secretKey: String?, projectID: String) {
        self.url = url
        self.publicKey = publicKey
        self.secretKey = secretKey
        self.projectID = projectID
    }
    
    /// Creates DSN object from a valid DSN string
    internal convenience init(_ dsnString: String) throws {
        guard let url = NSURL(string: dsnString),
            let projectID = DSN.projectID(from: url) else {
                throw SentryError.InvalidDSN
        }
        
        self.init(url: url,
                  publicKey: url.user,
                  secretKey: url.password,
                  projectID: projectID)
    }
    
    /// Tuple with the header name and header value
    internal var xSentryAuthHeader: XSentryAuthHeader {
        
        // Create header parts
        let headerParts: [(String, String?)] = [
            ("Sentry sentry_version", String(SentryClient.Info.sentryVersion)),
            ("sentry_client", "sentry-swift/\(SentryClient.Info.version)"),
            ("sentry_timestamp", String(Int(NSDate().timeIntervalSince1970))),
            ("sentry_key", publicKey),
            ("sentry_secret", secretKey)
        ]
        
        var ret: [String] = []
        headerParts.filter { $0.1 != nil }.forEach { ret.append("\($0.0)=\($0.1!)") }
        #if swift(>=3.0)
            let value = ret.joined(separator: ",")
        #else
            let value = ret.joinWithSeparator(",")
        #endif
        
        return ("X-Sentry-Auth", value)
    }
    
    /// Extracts the project ID from a URL
    private static func projectID(from url: NSURL) -> String? {
        // Should be receiving something like ["/", "12345"]
        // Removing first and getting second
        return url.pathComponents?.dropFirst().first
    }
}
