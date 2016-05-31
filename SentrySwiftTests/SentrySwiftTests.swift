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
		assert(SentryClient.shared != nil)
	}
	
	// MARK: Helpers
	
	func testDateSerialization() {
		let dateString = "2011-05-02T17:41:36"
		
		let date = NSDate.fromISO8601(dateString)
		assert(date != nil)
		assert(date?.iso8601 == dateString)
	}
	
	// MARK: DSN
	
	func testSecretDSN() {
		let dsnString = "https://username:password@app.getsentry.com/12345"
		
		guard let dsn = DSN(dsnString) else {
			assertionFailure("DSN is nil")
			return
		}
		assert(dsn.publicKey == "username")
		assert(dsn.secretKey == "password")
		assert(dsn.projectID == "12345")
		assert(dsn.serverURL.absoluteString == "https://app.getsentry.com/api/12345/store/")
	}
	
	func testPublicDSN() {
		let dsnString = "https://username@app.getsentry.com/12345"
		
		guard let dsn = DSN(dsnString) else {
			assertionFailure("DSN is nil")
			return
		}
		assert(dsn.publicKey == "username")
		assert(dsn.secretKey == nil)
		assert(dsn.projectID == "12345")
		assert(dsn.serverURL.absoluteString == "https://app.getsentry.com/api/12345/store/")
	}
	
	func testNoneDSN() {
		let dsnString = "https://app.getsentry.com/12345"
		
		guard let dsn = DSN(dsnString) else {
			assertionFailure("DSN is nil")
			return
		}
		assert(dsn.publicKey == nil)
		assert(dsn.secretKey == nil)
		assert(dsn.projectID == "12345")
		assert(dsn.serverURL.absoluteString == "https://app.getsentry.com/api/12345/store/")
	}
	
	func testBadDSN() {
		let dsnString = "https://app.getsentry.com"
		let dsn = DSN(dsnString)
		
		assert(dsn == nil)
	}
	
	// MARK: XSentryAuthHeader
	
	func testXSentryAuthHeader()  {
		let dsnString = "https://username:password@app.getsentry.com/12345"

		guard let dsn = DSN(dsnString) else {
			assertionFailure("DSN is nil")
			return
		}
		
		let header = dsn.xSentryAuthHeader
		assert(header.key == "X-Sentry-Auth")
		assert(header.value.rangeOfString("Sentry ") != nil)
		assert(header.value.rangeOfString("sentry_version=\(SentryClient.Info.sentryVersion)") != nil)
		assert(header.value.rangeOfString("sentry_client=sentry-swift/\(SentryClient.Info.version)") != nil)
		assert(header.value.rangeOfString("sentry_timestamp=") != nil)
		
		if let key = dsn.publicKey {
			assert(header.value.rangeOfString("sentry_key=\(key)") != nil)
		} else {
			assert(header.value.rangeOfString("sentry_key=") == nil)
		}
		
		if let key = dsn.secretKey {
			assert(header.value.rangeOfString("sentry_secret=\(key)") != nil)
		} else {
			assert(header.value.rangeOfString("sentry_secret=") == nil)
		}
	}
	
	// MARK: Event
	
	func testEventWithDefaults() {
		let message = "Thanks for looking at these tests"
		
		let event = Event(message)
		
		assert(event.eventID.characters.count == 32)
		assert(event.message == message)
		assert(event.level == .Error)
		assert(event.platform == "cocoa")
	}

	func testEventWithOptionals() {
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
		let exception: Exception = Exception(type: "Test", value: "test-value")

		let event = Event(message, timestamp: timestamp, level: level, logger: logger, culprit: culprit, serverName: serverName, release: release, tags: tags, modules: modules, extra: extra, fingerprint: fingerprint, exception: [exception])
		event.platform = platform
		
		// Required
		assert(event.eventID.characters.count == 32)
		assert(event.message == message)
		assert(event.timestamp == timestamp)
		assert(event.level == level)
		assert(event.platform == platform)
		
		// Optional
		assert(event.logger == logger)
		assert(event.culprit == culprit)
		assert(event.serverName == serverName)
		assert(event.releaseVersion == release)
		assert(event.exception! == [exception])
		assert(event.tags! == tags)
		assert(event.modules! == modules)
		assert(event.extra! == extra)
	}
	
	func testEventBuilder() {
		let event = Event.build("A bad thing happened", build: {
			$0.level = .Warning
			$0.tags = ["doot": "doot"]
		})
		
		assert(event.message == "A bad thing happened")
		assert(event.tags! == ["doot": "doot"])
		assert(event.level == .Warning)
	}
	
	// MARK: EventSerializable
	
	func testEventSerializableWithRequired() {
		let message = "Thanks for looking at these tests"
		
		let event = Event(message)
		let serialized = event.serialized
		
		// TODO: Find a less fugly way to test this
		assert((serialized["event_id"] as! String).characters.count == 32)
		assert(serialized["message"] as! String == message)
		assert(serialized["timestamp"] as? String != nil)
		assert(serialized["level"] as! String == "error")
		assert(serialized["platform"] as! String == "cocoa")
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
		assert((serialized["event_id"] as! String).characters.count == 32)
		assert(serialized["message"] as! String == message)
		assert(serialized["timestamp"] as! String == dateString)
		assert(serialized["level"] as! String == level.description)
		assert(serialized["platform"] as! String == platform)
		
		// Optional
		assert(serialized["logger"] as! String == logger)
		assert(serialized["culprit"] as! String == culprit)
		assert(serialized["server_name"] as! String == serverName)
		assert(serialized["tags"] as! EventTags == tags)
		assert(serialized["modules"] as! EventModules == modules)
		assert(serialized["extra"] as! EventExtra == extra)
		assert(serialized["fingerprint"] as! EventFingerprint == fingerprint)
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
		var event = Event("Lalalala")
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
		assert(event.tags! == [
			"tag_event": "value_event",
			"tag_client_event": "event_wins"
			])
		assert(event.extra! == [
			"extra_event": "value_event",
			"extra_client_event": "event_wins"
			])
		assert(event.user!.userID == "4")
		assert(event.user!.email! == "stuff@example.com")
		assert(event.user!.username! == "stuff")
		
		// Merge
		event.mergeProperties(from: client)
		
		// Test after merge
		assert(event.tags! == [
			"tag_client": "value_client",
			"tag_event": "value_event",
			"tag_client_event": "event_wins"
			])
		assert(event.extra! == [
			"extra_client": "value_client",
			"extra_event": "value_event",
			"extra_client_event": "event_wins"
			])
		assert(event.user!.userID == "4")
		assert(event.user!.email! == "stuff@example.com")
		assert(event.user!.username! == "stuff")
	}

    func testMergeEmptyEvent() {
        let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!

        let testTags = ["test": "foo"]
        let testExtra = ["bar": "baz"]
        let testUser = User(id: "3", email: "things@example.com", username: "things")

        client.tags = testTags
        client.extra = testExtra
        client.user = testUser

        var event = Event("such event")

        assert(event.tags == nil)
        assert(event.extra == nil)
        assert(event.user == nil)

		event.mergeProperties(from: client)
        assert(event.tags! == testTags)
        assert(event.extra! == testExtra)
        assert(event.user!.userID == testUser.userID)
        assert(event.user!.email! == testUser.email!)
        assert(event.user!.username! == testUser.username!)
    }

    func testMergeEmptyClient() {
        let client = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")!

        assert(client.tags == nil)
        assert(client.extra == nil)
        assert(client.user == nil)

        let testTags = ["test": "foo"]
        let testExtra = ["bar": "baz"]
        let testUser = User(id: "3", email: "things@example.com", username: "things")

        var event = Event("such event")

        event.tags = testTags
        event.extra = testExtra
        event.user = testUser

		event.mergeProperties(from: client)
        assert(event.tags! == testTags)
        assert(event.extra! == testExtra)
        assert(event.user!.userID == testUser.userID)
        assert(event.user!.email! == testUser.email!)
        assert(event.user!.username! == testUser.username!)
    }
}

/// A small hack to compare dictionaries
public func ==(lhs: [String: AnyObject], rhs: [String: AnyObject] ) -> Bool {
	return NSDictionary(dictionary: lhs).isEqualToDictionary(rhs)
}
