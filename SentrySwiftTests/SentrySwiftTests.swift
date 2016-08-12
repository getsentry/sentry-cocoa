//
//  SentrySwiftTests.swift
//  SentrySwiftTests
//
//  Created by Josh Holtz on 12/16/15.
//
//

import XCTest
import SentrySwift
@testable import SentrySwift

class SentrySwiftTests: XCTestCase {
	
	let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
	
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func testSharedClient() {
		SentryClient.shared = client
		XCTAssertNotNil(SentryClient.shared)
	}
	
	// MARK: Helpers
	
	func testDateSerialization() {
		let dateString = "2011-05-02T17:41:36"
		
		let date = NSDate.fromISO8601(dateString)
		XCTAssertNotNil(date)
		XCTAssertEqual(date?.iso8601, dateString)
	}
	
	// MARK: DSN
	
	func testSecretDSN() {
		let dsnString = "https://username:password@app.getsentry.com/12345"
		
		do {
			let dsn = try DSN(dsnString)
			
			XCTAssertEqual(dsn.publicKey, "username")
			XCTAssertEqual(dsn.secretKey, "password")
			XCTAssertEqual(dsn.projectID, "12345")
			XCTAssertEqual(dsn.serverURL.absoluteString, "https://app.getsentry.com/api/12345/store/")
		} catch {
			XCTFail("DSN is nil")
		}
	}
	
	func testPublicDSN() {
		let dsnString = "https://username@app.getsentry.com/12345"
		
		do {
			let dsn = try DSN(dsnString)
			
			XCTAssertEqual(dsn.publicKey, "username")
			XCTAssertEqual(dsn.secretKey, nil)
			XCTAssertEqual(dsn.projectID, "12345")
			XCTAssertEqual(dsn.serverURL.absoluteString, "https://app.getsentry.com/api/12345/store/")
		} catch {
			XCTFail("DSN is nil")
		}
		
	}
	
	func testNoneDSN() {
		let dsnString = "https://app.getsentry.com/12345"
		
		do {
			let dsn = try DSN(dsnString)
			
			XCTAssertEqual(dsn.publicKey, nil)
			XCTAssertEqual(dsn.secretKey, nil)
			XCTAssertEqual(dsn.projectID, "12345")
			XCTAssertEqual(dsn.serverURL.absoluteString, "https://app.getsentry.com/api/12345/store/")
		} catch {
			XCTFail("DSN is nil")
		}
	}
	
	func testBadDSN() {
		let dsnString = "https://app.getsentry.com"
		
		do {
			let _ = try DSN(dsnString)
			
			XCTFail("DSN should not have been created")
		} catch {
			
		}
	}
	
	// MARK: XSentryAuthHeader
	
	func testXSentryAuthHeader()  {
		let dsnString = "https://username:password@app.getsentry.com/12345"

		guard let dsn = try? DSN(dsnString) else {
			XCTFail("DSN is nil")
			return
		}
		
		let header = dsn.xSentryAuthHeader
		XCTAssertEqual(header.key, "X-Sentry-Auth")
		XCTAssertNotNil(rangeOfString(header.value, rangeString: "Sentry "))
		XCTAssertNotNil(rangeOfString(header.value, rangeString: "sentry_version=\(SentryClient.Info.sentryVersion)"))
		XCTAssertNotNil(rangeOfString(header.value, rangeString: "sentry_client=sentry-swift/\(SentryClient.Info.version)"))
		XCTAssertNotNil(rangeOfString(header.value, rangeString: "sentry_timestamp="))
		
		if let key = dsn.publicKey {
			XCTAssertNotNil(rangeOfString(header.value, rangeString: "sentry_key=\(key)"))
		} else {
			XCTAssertNil(rangeOfString(header.value, rangeString: "sentry_key=") == nil)
		}
		
		if let key = dsn.secretKey {
			XCTAssertNotNil(rangeOfString(header.value, rangeString: "sentry_secret=\(key)"))
		} else {
			XCTAssertNil(rangeOfString(header.value, rangeString: "sentry_secret="))
		}
	}

	private func rangeOfString(_ string: String, rangeString: String) -> Range<String.Index>? {
		#if swift(>=3.0)
			return string.range(of: rangeString)
		#else
			return string.rangeOfString(rangeString)
		#endif
	}
	
	// MARK: Event
	
	func testEventWithDefaults() {
		let message = "Thanks for looking at these tests"
		
		let event = Event(message)
		
		XCTAssertEqual(event.eventID.characters.count, 32)
		XCTAssertEqual(event.message, message)
		XCTAssert(event.level == .Error)
		XCTAssertEqual(event.platform, "cocoa")
	}

	func testEventWithOptionals() {
		let dateString = "2011-05-02T17:41:36"
		
		// Required
		let message = "Enjoy this library"
		guard let timestamp = NSDate.fromISO8601(dateString) else {
			XCTFail("timestamp should not be nil")
			return
		}
		let level = SentrySeverity.Info
		let platform = "osx"
		
		// Optional
		let logger = "paul.bunyan"
		let culprit = "hewey, dewey, and luey"
		let serverName = "Janis"
		let release = "by The Tea Party"
		let tags: EventTags = ["doot": "doot"]
		let modules: EventModules = ["2spooky": "4you"]
		let extra: EventExtra = ["power rangers": 5, "tmnt": 4]
		let fingerprint: EventFingerprint = ["this", "happend", "right", "here"]
		let exception: Exception = Exception(value: "test-value", type: "Test")

		let event = Event(message, timestamp: timestamp, level: level, logger: logger, culprit: culprit, serverName: serverName, release: release, tags: tags, modules: modules, extra: extra, fingerprint: fingerprint, exceptions: [exception])
		event.platform = platform
		
		// Required
		XCTAssertEqual(event.eventID.characters.count, 32)
		XCTAssertEqual(event.message, message)
		XCTAssertEqual(event.timestamp, timestamp)
		XCTAssertEqual(event.level, level)
		XCTAssertEqual(event.platform, platform)
		
		// Optional
		XCTAssertEqual(event.logger, logger)
		XCTAssertEqual(event.culprit, culprit)
		XCTAssertEqual(event.serverName, serverName)
		XCTAssertEqual(event.releaseVersion, release)
		XCTAssertEqual(event.exceptions!, [exception])
		XCTAssertEqual(event.tags, tags)
		XCTAssertEqual(event.modules!, modules)
		XCTAssert(event.extra == extra)
	}
	
	func testEventBuilder() {
		let event = Event.build("A bad thing happened", build: {
			$0.level = .Warning
			$0.tags = ["doot": "doot"]
		})
		
		XCTAssertEqual(event.message, "A bad thing happened")
		XCTAssertEqual(event.tags, ["doot": "doot"])
		XCTAssert(event.level == .Warning)
	}
	
	// MARK: EventSerializable
	
	func testEventSerializableWithRequired() {
		let message = "Thanks for looking at these tests"
		
		let event = Event(message)
		let serialized = event.serialized
		
		// TODO: Find a less fugly way to test this
		XCTAssertEqual((serialized["event_id"] as! String).characters.count, 32)
		XCTAssertEqual(serialized["message"] as? String, message)
		XCTAssertNotNil(serialized["timestamp"] as? String)
		XCTAssertEqual(serialized["level"] as? String, "error")
		XCTAssertEqual(serialized["platform"] as? String, "cocoa")
		
		// SDK
		let sdk = serialized["sdk"] as! [String: String]
		XCTAssertEqual(sdk["name"], "sentry-swift")
		XCTAssertEqual(sdk["version"], SentryClient.Info.version)
		
		// Device
		let context = serialized["contexts"] as! [String: AnyObject]
		XCTAssertNotNil(context["os"])
		XCTAssertNotNil(context["device"])
		
		#if os(iOS)
			XCTAssertEqual((context["os"] as! [String: AnyObject])["name"] as? String, "iOS")
		#elseif os(tvOS)
			XCTAssertEqual((context["os"] as! [String: AnyObject])["name"] as? String, "tvOS")
		#elseif os(OSX)
			XCTAssertEqual((context["os"] as! [String: AnyObject])["name"] as? String, "macOS")
		#endif
	}
	
	func testEventSerializableWithOptional() {
		let dateString = "2011-05-02T17:41:36"
		
		// Required
		let message = "Enjoy this library"
		guard let timestamp = NSDate.fromISO8601(dateString) else {
			assertionFailure("timestamp should not be nil")
			return
		}
		let level = SentrySeverity.Info
		let platform = "osx"
		
		// Optional
		let logger = "paul.bunyan"
		let culprit = "hewey, dewey, and luey"
		let serverName = "Janis"
		let release = "by The Tea Party"
		let tags: EventTags = ["doot": "doot"]
		let modules: EventModules = ["2spooky": "4you"]
		let extra: EventExtra = ["power rangers": 5, "tmnt": 4]
		let fingerprint: EventFingerprint = ["this", "happend", "right", "here"]
		
		let event = Event(message, timestamp: timestamp, level: level, logger: logger, culprit: culprit, serverName: serverName, release: release, tags: tags, modules: modules, extra: extra, fingerprint: fingerprint)
		event.platform = platform
		let serialized = event.serialized
		
		// TODO: Find a less fugly way to test this
		// Required
		XCTAssertEqual((serialized["event_id"] as! String).characters.count, 32)
		XCTAssertEqual(serialized["message"] as? String, message)
		XCTAssertEqual(serialized["timestamp"] as? String, dateString)
		XCTAssertEqual(serialized["level"] as? String, level.description)
		XCTAssertEqual(serialized["platform"] as? String, platform)
		
		// Optional
		XCTAssertEqual(serialized["logger"] as? String, logger)
		XCTAssertEqual(serialized["culprit"] as? String, culprit)
		XCTAssertEqual(serialized["server_name"] as? String, serverName)
		XCTAssertEqual(serialized["tags"] as! EventTags, tags)
		XCTAssertEqual(serialized["modules"] as! EventModules, modules)
		XCTAssert(serialized["extra"] as! EventExtra == extra)
		XCTAssertEqual(serialized["fingerprint"] as! EventFingerprint, fingerprint)
	}
	
	// MARK: EventProperties
	
	func testEventProperties() {
		// Create client
		let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!
		client.tags = [
			"tag_client": "value_client",
			"tag_client_event": "THIS SHOULDN'T SHOW AT ALL"
		]
		client.extra = [
			"extra_client": "value_client",
			"extra_client_event": "THIS SHOULDN'T SHOW AT ALL"
		]
		client.user = User(id: "3", email: "things@example.com", username: "things")
		
		// Create event
		let event = Event("Lalalala")
		event.tags = [
			"tag_event": "value_event",
			"tag_client_event": "event_wins"
		]
		event.extra = [
			"extra_event": "value_event",
			"extra_client_event": "event_wins"
		]
		event.user = User(id: "4", email: "stuff@example.com", username: "stuff")
		
		// Test before merge
		XCTAssertEqual(event.tags, [
			"tag_event": "value_event",
			"tag_client_event": "event_wins"
			])
		XCTAssert(event.extra == [
			"extra_event": "value_event",
			"extra_client_event": "event_wins"
			])
		XCTAssertEqual(event.user!.userID, "4")
		XCTAssertEqual(event.user!.email!, "stuff@example.com")
		XCTAssertEqual(event.user!.username!, "stuff")
        
        // Merge
		event.tags.unionInPlace(client.tags ?? [:])
		event.extra.unionInPlace(client.extra ?? [:])
		
		// Test after merge
		XCTAssert(event.tags == [
			"tag_client": "value_client",
			"tag_event": "value_event",
			"tag_client_event": "event_wins"
			])
		XCTAssert(event.extra == [
			"extra_client": "value_client",
			"extra_event": "value_event",
			"extra_client_event": "event_wins"
			])
		XCTAssertEqual(event.user!.userID, "4")
		XCTAssertEqual(event.user!.email!, "stuff@example.com")
		XCTAssertEqual(event.user!.username!, "stuff")
	}

    func testMergeEmptyEvent() {
        let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!

        let testTags = ["test": "foo"]
        let testExtra = ["bar": "baz"]
        let testUser = User(id: "3", email: "things@example.com", username: "things")

        client.tags = testTags
        client.extra = testExtra
        client.user = testUser

        let event = Event("such event")

        XCTAssertEqual(event.tags, [:])
        XCTAssert(event.extra == [:])
        XCTAssertNil(event.user)

        event.tags.unionInPlace(client.tags ?? [:])
        event.extra.unionInPlace(client.extra ?? [:])
        event.user = event.user ?? client.user

        XCTAssertEqual(event.tags, testTags)
        XCTAssert(event.extra == testExtra)
        XCTAssertEqual(event.user!.userID, testUser.userID)
        XCTAssertEqual(event.user!.email!, testUser.email!)
        XCTAssertEqual(event.user!.username!, testUser.username!)
    }

    func testMergeEmptyClient() {
        let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!

		XCTAssertEqual(client.tags, [:])
		XCTAssert(client.extra == [:])
		XCTAssertNil(client.user)

        let testTags = ["test": "foo"]
        let testExtra = ["bar": "baz"]
        let testUser = User(id: "3", email: "things@example.com", username: "things")

        let event = Event("such event")

        event.tags = testTags
        event.extra = testExtra
        event.user = testUser
        
        event.tags.unionInPlace(client.tags)
        event.extra.unionInPlace(client.extra)

		XCTAssertEqual(event.tags, testTags)
		XCTAssert(event.extra == testExtra)
		XCTAssertEqual(event.user!.userID, testUser.userID)
		XCTAssertEqual(event.user!.email!, testUser.email!)
		XCTAssertEqual(event.user!.username!, testUser.username!)
    }
}

/// A small hack to compare dictionaries
public func ==(lhs: [String: AnyObject], rhs: [String: AnyObject] ) -> Bool {
	#if swift(>=3.0)
		return NSDictionary(dictionary: lhs).isEqual(to: rhs)
	#else
		return NSDictionary(dictionary: lhs).isEqualToDictionary(rhs)
	#endif
}
