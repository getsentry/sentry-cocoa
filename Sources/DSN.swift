//
//  DSN.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/6/16.
//
//

import Foundation

internal typealias XSentryAuthHeader = (key: String, value: String)
internal typealias SentryURLs = (storeURL: NSURL, userFeedbackURL: NSURL)

/// A class to hold DSN information and populate X-Sentry-Auth header
internal class DSN: NSObject {

	internal let dsn: NSURL
	internal let urls: SentryURLs
	internal let publicKey: String?
	internal let secretKey: String?
	internal let projectID: String

	internal init(dsn: NSURL, urls: SentryURLs, publicKey: String?, secretKey: String?, projectID: String) {
		self.dsn = dsn
		self.publicKey = publicKey
		self.secretKey = secretKey
		self.projectID = projectID
        self.urls = urls
	}

	/// Creates DSN object from a valid DSN string
	internal convenience init(_ dsnString: String) throws {
		var dsn: NSURL?
        var storeURL: NSURL?
        var userFeedbackURL: NSURL?
		var publicKey: String?
		var secretKey: String?
		var projectID: String?

		if let url = NSURL(string: dsnString),
			let host = url.host,
			let id = DSN.projectID(from: url) {

			// Setting properties
			dsn = url
			publicKey = url.user
			secretKey = url.password
			projectID = id

			// Setting components to create NSURL
			let components = NSURLComponents()
			components.scheme = url.scheme
			components.host = host
			components.path = "/api/\(id)/store/"
			components.port = url.port

			#if swift(>=3.0)
				storeURL = components.url as NSURL?
			#else
				storeURL = components.URL
			#endif
            
            // Setting components to create NSURL
            let userFeedbackComponents = NSURLComponents()
            userFeedbackComponents.scheme = url.scheme
            userFeedbackComponents.host = host
            userFeedbackComponents.path = "/api/embed/error-page/"
            userFeedbackComponents.port = url.port
            
            #if swift(>=3.0)
                userFeedbackURL = components.url as NSURL?
            #else
                userFeedbackURL = components.URL
            #endif
		}

		guard let theDsn = dsn, let theStoreURL = storeURL, let theProjectID = projectID else {
			throw SentryError.InvalidDSN
		}
        self.init(dsn: theDsn,
                  urls: SentryURLs(storeURL: theStoreURL, userFeedbackURL: theStoreURL), // TODO theStoreURL
                  publicKey: publicKey,
                  secretKey: secretKey,
                  projectID: theProjectID)
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
		headerParts.filter() { $0.1 != nil }.forEach() { ret.append("\($0.0)=\($0.1!)") }
		#if swift(>=3.0)
			let value = ret.joined(separator: ",")
		#else
			let value = ret.joinWithSeparator(",")
		#endif

		return ("X-Sentry-Auth", value)
	}

    /// Extracts the public DSN from a URL
    internal func enrichedUserFeedbackURL() -> NSURL {
        return NSURL(string: "http://808671937ad740ec9cd39c35b26c7264@dgriesser-7b0957b1732f38a5e205.eu.ngrok.io/api/embed/error-page/?eventId=69AEB5B5A62B4C4EA85C4380EC98B9C6&dsn=http%3a%2f%2f808671937ad740ec9cd39c35b26c7264%40dgriesser-7b0957b1732f38a5e205.eu.ngrok.io%2f1&email=daniel.griesser.86%40gmail.com")!
    }
    
	/// Extracts the project ID from a URL
	private static func projectID(from url: NSURL) -> String? {
		// Should be receiving something like ["/", "12345"]
		// Removing first and getting second
		return url.pathComponents?.dropFirst().first
	}
}
