//
//  DSN.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/6/16.
//
//

import Foundation

internal typealias XSentryAuthHeader = (key: String, value: String)

/// A class to hold DSN information and populate X-Sentry-Auth header
internal class DSN: NSObject {

	internal let dsn: URL
	internal let serverURL: URL
	internal let publicKey: String?
	internal let secretKey: String?
	internal let projectID: String

	internal init(dsn: URL, serverURL: URL, publicKey: String?, secretKey: String?, projectID: String) {
		self.dsn = dsn
		self.serverURL = serverURL
		self.publicKey = publicKey
		self.secretKey = secretKey
		self.projectID = projectID
	}

	/// Creates DSN object from a valid DSN string
	internal convenience init(_ dsnString: String) throws {
		var dsn: URL?
		var serverURL: URL?
		var publicKey: String?
		var secretKey: String?
		var projectID: String?

		if let url = URL(string: dsnString),
		let host = url.host,
		let id = DSN.projectID(from: url) {

			// Setting properties
			dsn = url
			publicKey = url.user
			secretKey = url.password
			projectID = id

			// Setting componts to create NSURL
			let components = NSURLComponents()
			components.scheme = url.scheme
			components.host = host
			components.path = "/api/\(id)/store/"
			components.port = url.port as NSNumber?

			serverURL = components.url
		}

		guard let theDsn = dsn, let theServerURL = serverURL, let theProjectID = projectID else {
			throw SentryError.invalidDSN
		}
		self.init(dsn: theDsn, serverURL: theServerURL, publicKey: publicKey, secretKey: secretKey, projectID: theProjectID)
	}

	/// Tuple with the header name and header value
	internal var xSentryAuthHeader: XSentryAuthHeader {

		// Create header parts
		let headerParts: [(String, String?)] = [
				("Sentry sentry_version", String(SentryClient.Info.sentryVersion)),
				("sentry_client", "sentry-swift/\(SentryClient.Info.version)"),
				("sentry_timestamp", String(Int(Date().timeIntervalSince1970))),
				("sentry_key", self.publicKey),
				("sentry_secret", self.secretKey)
		]

		var ret: [String] = []
		headerParts.filter() { $0.1 != nil }.forEach() { ret.append("\($0.0)=\($0.1!)") }
		let value = ret.joined(separator: ",")

		return ("X-Sentry-Auth", value)
	}

	/// Extracts the project ID from a URL
	private static func projectID(from url: URL) -> String? {
		// Should be receiving something like ["/", "12345"]
		// Removing first and getting second
		return url.pathComponents.dropFirst().first
	}
}
