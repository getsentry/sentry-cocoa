//
//  SentrySwiftTests.swift
//  SentrySwiftTests
//
//  Created by Josh Holtz on 12/16/15.
//
//

import XCTest
@testable import Sentry
@testable import KSCrash

class SentrySwiftTests: XCTestCase {
	
	var client = SentrySwiftTestHelper.sentryMockClient
	
    override func setUp() {
        super.setUp()
        client = SentrySwiftTestHelper.sentryMockClient
        SentryClient.shared = client
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func testSharedClient() {
		SentryClient.shared = client
		XCTAssertNotNil(SentryClient.shared)
	}
    
    func testSetExtraAndTags() {
        let client = SentrySwiftTestHelper.sentryMockClient
        client.tags = ["1": "2"]
        client.addTag("a", value: "b")
        XCTAssertEqual(client.tags["1"], "2")
        XCTAssertEqual(client.tags["a"], "b")
        
        client.extra = ["1": "3"]
        client.addExtra("a", value: "c")
        XCTAssertEqual(client.extra["1"] as? String, "3")
        XCTAssertEqual(client.extra["a"] as? String, "c")
    }
    
    func testRemoveSentryInternalExtras() {
        let event = SentrySwiftTestHelper.demoFatalEvent
        event.extra = ["1": "3"]
        event.addExtra("a", value: "c")
        event.addExtra("__sentry_stacktrace", value: "c")
        event.addExtra("__sentryasda", value: "c")
        
        let serialized = event.serialized
        let extra = serialized["extra"] as! EventExtra
        XCTAssertEqual(extra.count, 2)
        XCTAssertEqual(extra["1"] as? String, "3")
        XCTAssertEqual(extra["a"] as? String, "c")
        XCTAssertNil(extra["__sentry_stacktrace"])
    }
    
    #if swift(>=3.0)
    
    func testImmutableCrashProperties() {
        let asyncExpectation = expectation(description: "testImmutableCrashProperties")
        
        SentryClient.shared = client
        SentryClient.logLevel = .debug
        
        SentryClient.shared?.startCrashHandler()
        
        SentryClient.shared?.tags = ["a": "b"]
        SentryClient.shared?.extra = ["1": "2"]
        SentryClient.shared?.user = User(id: "1", email: "a@b.com", username: "test", extra: ["x": "y"])
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test1"))
        
        KSCrash.sharedInstance().deleteAllReports()
        
        KSCrash.sharedInstance().reportUserException("", reason: "", language: SentryClient.CrashLanguages.reactNative, lineOfCode: "", stackTrace: [""], logAllThreads: false, terminateProgram: false)
        
        SentryClient.shared?.tags = ["b": "c"]
        SentryClient.shared?.extra = ["2": "3"]
        SentryClient.shared?.user = User(id: "2", email: "b@c.com", username: "test", extra: ["x": "y"])
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "test2"))
        
        SentryClient.shared?.beforeSendEventBlock = {
            XCTAssertEqual($0.tags, ["a": "b"])
            XCTAssertEqual($0.extra["1"] as? String, "2")
            XCTAssertEqual($0.user?.email, "a@b.com")
            XCTAssertEqual($0.breadcrumbsSerialized?.count, 1)
            asyncExpectation.fulfill()
        }
        
        SentryClient.shared?.crashHandler?.sendAllReports()
        
        waitForExpectations(timeout: 5) { error in
            KSCrash.sharedInstance().deleteAllReports()
            XCTAssertNil(error)
        }
        
        KSCrash.sharedInstance().reportUserException("", reason: "", language: SentryClient.CrashLanguages.reactNative, lineOfCode: "", stackTrace: [""], logAllThreads: false, terminateProgram: false)
        
        let asyncExpectation2 = expectation(description: "testSharedProperties2")
        
        SentryClient.shared?.beforeSendEventBlock = {
            XCTAssertEqual($0.tags, ["b": "c"])
            XCTAssertEqual($0.extra["2"] as? String, "3")
            XCTAssertEqual($0.user?.email, "b@c.com")
            XCTAssertEqual($0.breadcrumbsSerialized?.count, 2)
            asyncExpectation2.fulfill()
        }
        
        SentryClient.shared?.crashHandler?.sendAllReports()
        
        waitForExpectations(timeout: 5) { error in
            KSCrash.sharedInstance().deleteAllReports()
            XCTAssertNil(error)
        }
        
    }
    
    func testSharedProperties() {
        let asyncExpectation = expectation(description: "testSharedProperties")
        
        SentryClient.shared = client
        
        SentryClient.shared?.tags = ["a": "b"]
        SentryClient.shared?.extra = ["1": "2"]
        SentryClient.shared?.user = User(id: "1", email: "a@b.com", username: "test", extra: ["x": "y"])
        
        SentryClient.shared?.startCrashHandler()
        SentryClient.shared?.captureMessage("test")
        
        SentryClient.shared?.beforeSendEventBlock = {
            XCTAssertEqual($0.tags, ["a": "b"])
            XCTAssertEqual($0.extra["1"] as? String, "2")
            XCTAssertEqual($0.user?.email, "a@b.com")
            asyncExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
        }
        
        let asyncExpectation2 = expectation(description: "testSharedProperties2")
        
        SentryClient.shared?.tags = ["b": "c"]
        SentryClient.shared?.extra = ["2": "3"]
        SentryClient.shared?.user = User(id: "2", email: "b@c.com", username: "test", extra: ["x": "y"])
        
        SentryClient.shared?.captureMessage("test")
        
        SentryClient.shared?.beforeSendEventBlock = {
            XCTAssertEqual($0.tags, ["b": "c"])
            XCTAssertEqual($0.extra["2"] as? String, "3")
            XCTAssertEqual($0.user?.email, "b@c.com")
            asyncExpectation2.fulfill()
        }
        
        waitForExpectations(timeout: 5) { error in
           XCTAssertNil(error)
        }
    }
    #endif
    
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
			XCTAssertEqual(dsn.url.absoluteString, "https://username:password@app.getsentry.com/12345")
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
			XCTAssertEqual(dsn.url.absoluteString, "https://username@app.getsentry.com/12345")
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
			XCTAssertEqual(dsn.url.absoluteString, "https://app.getsentry.com/12345")
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
		XCTAssert(event.level == .error)
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
		let level = Severity.info
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
			$0.level = .warning
			$0.tags = ["doot": "doot"]
		})
		
		XCTAssertEqual(event.message, "A bad thing happened")
		XCTAssertEqual(event.tags, ["doot": "doot"])
		XCTAssert(event.level == .warning)
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
		let level = Severity.info
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
		event.tags.unionInPlace(client.tags)
		event.extra.unionInPlace(client.extra)
		
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

        event.tags.unionInPlace(client.tags)
        event.extra.unionInPlace(client.extra)
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
    
    #if os(iOS)
    func testUserFeedbackController() {
        client.enableUserFeedbackAfterFatalEvent()
        
        let controllers = client.userFeedbackControllers()
        
        XCTAssertEqual(controllers?.userFeedbackTableViewController, client.userFeedbackTableViewController())
        XCTAssertEqual(controllers?.navigationController, client.userFeedbackNavigationViewController())
        
        let controllers2 = client.userFeedbackControllers()
        
        XCTAssertEqual(controllers?.userFeedbackTableViewController, controllers2?.userFeedbackTableViewController)
        XCTAssertEqual(controllers?.navigationController, controllers2?.navigationController)
    }
    #endif
    
    func testConvertAttributesToNonNil() {
        var serialized: SerializedTypeDictionary {
            
            // Create attributes list
            var attributes: [Attribute] = []
            
            attributes.append(("filename", "1"))
            attributes.append(("function", nil))
            attributes.append(("module", "2"))
            
            return convertAttributes(attributes)
        }
        
        XCTAssertEqual(serialized["filename"] as? String, "1")
        XCTAssertEqual(serialized["module"] as? String, "2")
        XCTAssertEqual(serialized.count, 2)
        XCTAssertNil(serialized["function"])
    }
    
    
    #if swift(>=3.0)
    func testCaptureEvent() {
        let asyncExpectation = expectation(description: "testCaptureEvent")
        
        let event = Event.build("Another example 4") {
            $0.level = .fatal
            $0.tags = ["status": "test"]
            $0.extra = [
                "name": "Josh Holtz",
                "favorite_power_ranger": "green/white"
            ]
        }
        client.breadcrumbs.add(Breadcrumb(category: "captureEvent"))
        client.captureEvent(event)
        
        let deadlineTime = DispatchTime.now() + .milliseconds(50)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            asyncExpectation.fulfill()
        }
        waitForExpectations(timeout: 2) { error in
            if let breadcrumbs = event.serialized["breadcrumbs"] as? [Dictionary<String, AnyType>] {
                XCTAssertEqual(breadcrumbs.first?["category"] as? String, "captureEvent")
            }
        }
    }
    
    func testCaptureStacktrace() {
        let asyncExpectation = expectation(description: "testCaptureStacktrace")
        
        SentryClient.shared?.startCrashHandler()
        
        SentryClient.shared?.snapshotStacktrace()
        SentryClient.shared?.beforeSendEventBlock = {
            XCTAssertNil($0.threads)
            XCTAssertNil($0.debugMeta)
            $0.fetchStacktrace()
            XCTAssertNotNil($0.threads)
            XCTAssertNotNil($0.debugMeta)
            asyncExpectation.fulfill()
        }
        SentryClient.shared?.captureMessage("Test")
        
        waitForExpectations(timeout: 1) { error in
            
        }
    }
    #endif
    
    func testNoValidJSON() {
        XCTAssertNotNil(Event.build("Alarm is too far in future") {
                $0.level = .warning
                $0.extra = [
                    "Alarm ID": "12",
                    "Query Time" : 12,
                    "Local Query Time" : NSDate(),
                    "Local Current Time" : "123",
                    "Seconds Since Query" : "123123",
                    "Seconds to arrival" : 123.1,
                ]
            }.serialized["extra"])
        
        XCTAssertNotNil(Event.build("Alarm is too far in future") {
            $0.level = .warning
            $0.extra = [
                "Alarm ID": "12",
                "Query Time" : 12,
                "Local Query Time" : "asda",
                "Local Current Time" : "123",
                "Seconds Since Query" : "123123",
                "Seconds to arrival" : 123.1,
            ]
            }.serialized["extra"])
        
        XCTAssertNotNil(Event.build("Alarm is too far in future") {
            $0.level = .warning
            $0.tags = [
                "Alarm ID": "12",
                "Query Time" : "12",
                "Local Query Time" : "asda",
                "Local Current Time" : "123",
                "Seconds Since Query" : "123123",
                "Seconds to arrival" : "123.1",
            ]
            }.serialized["tags"])
    }
    
    func testSaveEvent() {
        let client = SentrySwiftTestHelper.sentryMockClient
        for event in client.savedEvents(since: (Date().timeIntervalSince1970 + 1000)) {
            event.deleteEvent()
        }
        let event = Event.build("Another example 4") {
            $0.level = .fatal
            $0.tags = ["status": "test"]
            $0.extra = [
                "name": "Josh Holtz",
                "favorite_power_ranger": "green/white"
            ]
        }
        client.saveEvent(event)
        XCTAssertEqual(client.savedEvents().count, 0)
        XCTAssertEqual(client.savedEvents(since: (Date().timeIntervalSince1970 + 100)).count, 1)
        for event in client.savedEvents(since: (Date().timeIntervalSince1970 + 1000)) {
            event.deleteEvent()
        }
    }
    
    func testSanitation() {
        let url: NSURL! = NSURL(string: "http://getsentry.io")
        let error = NSError(domain: "domain", code: -1, userInfo: nil)
        
        #if swift(>=3.0)
        let boolNumber = NSNumber(value: true)
        #else
        let boolNumber = NSNumber(bool: false)
        #endif
        
        let array = ["string", url, boolNumber, NSDate(), error] as [AnyType]
        
        XCTAssert(JSONSerialization.isValidJSONObject(sanitize(array)))
    
        let event = Event.build("message") { _ in }
        let dict: [String: AnyType] = ["key": array, "customObject": event]
        XCTAssert(JSONSerialization.isValidJSONObject(sanitize(dict)))
    }
    
    #if swift(>=3.0)
    #if os(iOS)
    func testSwizzle() {
        XCTAssertEqual(client.breadcrumbs.crumbs.count, 0)
        
        client.enableUserFeedbackAfterFatalEvent()
    
        let controllers = client.userFeedbackControllers()!
        
        controllers.navigationController.viewDidAppear(true)
        
        XCTAssertEqual(client.breadcrumbs.crumbs.count, 0)
        
        // ---------------
        
        client.enableAutomaticBreadcrumbTracking()
        
        controllers.navigationController.viewDidAppear(true)
        
        XCTAssertEqual(client.breadcrumbs.crumbs.count, 1)
    }
    #endif
    #endif
}

/// A small hack to compare dictionaries
public func ==(lhs: [String: AnyType], rhs: [String: AnyType] ) -> Bool {
	#if swift(>=3.0)
		return NSDictionary(dictionary: lhs).isEqual(to: rhs)
	#else
		return NSDictionary(dictionary: lhs).isEqualToDictionary(rhs)
	#endif
}
