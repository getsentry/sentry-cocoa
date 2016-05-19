//
//  DSN.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/6/16.
//
//

import Foundation

/// A struct to hold infromation about the DSN
/// and to generate the X-Sentry-Auth header.
@objc public class DSN: NSObject {
	
	public let dsn: NSURL
	public let serverURL: NSURL
	public let publicKey: String?
	public let secretKey: String?
	public let projectID: String
	
	init(dsn: NSURL, serverURL: NSURL, publicKey: String?, secretKey: String?, projectID: String) {
		self.dsn = dsn
		self.serverURL = serverURL
		self.publicKey = publicKey
		self.secretKey = secretKey
		self.projectID = projectID
	}
	
	/// Can create a DSN struct from a string. If the string is not a
	/// valid DSN format, a nil will be returned
	public convenience init?(_ dsnString: String) {
		var dsn: NSURL?
		var serverURL: NSURL?
		var publicKey: String?
		var secretKey: String?
		var projectID: String?
		
		if let url = NSURL(string: dsnString),
			host = url.host,
			id = DSN.getProjectID(url) {
				
				// Setting properties
				dsn = url
				publicKey = url.user
				secretKey = url.password
				projectID = id
				
				// Creating components for serverURL
				let path = "/api/\(id)/store/"
				
				// Setting componts to create NSURL
				let components = NSURLComponents()
				components.scheme = url.scheme
				components.host = host
				components.path = path
				components.port = url.port
				
				serverURL = components.URL
		}

		guard let theDsn = dsn, theServerURL = serverURL, theProjectID = projectID else {
			return nil
		}
		self.init(dsn: theDsn, serverURL: theServerURL, publicKey: publicKey, secretKey: secretKey, projectID: theProjectID)
	}
	
	public typealias XSentryAuthHeader = (key: String, value: String)
	
	/// Creates a tuple with the header name and header value
	public var xSentryAuthHeader: XSentryAuthHeader {
		// Header parts
		let headerParts: [(String, String?)] = [
			("Sentry sentry_version", String(SentryInfo.sentryVersion)),
			("sentry_client", "raven-swift/\(SentryInfo.version)"),
			("sentry_timestamp", String(Int(NSDate().timeIntervalSince1970))),
			("sentry_key", self.publicKey),
			("sentry_secret", self.secretKey)
		]
		
		// Combine parts into comma, delimited string
		let value = headerParts.reduce([], combine: { (combined, keyValue) -> [String] in
			guard let value = keyValue.1 else {
				return combined
			}
			return combined + ["\(keyValue.0)=\(value)"]
		}).joinWithSeparator(",")
		
		return ("X-Sentry-Auth", value)
	}

	/// Strips the project ID from a URL
	private static func getProjectID(url: NSURL) -> String? {
		return url.lastPathComponent
	}
}
