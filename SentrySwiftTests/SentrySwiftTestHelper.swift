//
//  SentrySwiftTestHelper.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 05/11/16.
//
//

import Foundation
@testable import SentrySwift

class MockRequestManager: RequestManager {
    required init(session: URLSession) {
        
    }
    
    func addRequest(_ request: URLRequest, finished: SentryEndpointRequestFinished? = nil) {
        finished?(true)
    }
    
    var isReady: Bool {
        return true
    }
    
}

class TestCrashHandler: CrashHandler {
    required init(client: SentryClient) {
    }
    
    var crashReportingHasStarted = false
    func startCrashReporting() {
        crashReportingHasStarted = true
    }
    
    func sendAllReports() {
        
    }
    
    var breadcrumbsSerialized: BreadcrumbStore.SerializedType?
    var releaseVersion: String?
    var buildNumber: String?
    var tags: EventTags = [:]
    var extra: EventExtra = [:]
    var user: User?
}

class SentrySwiftTestHelper {
    
    typealias JSONCrashFile = [String: AnyObject]
    
    static var sentryMockClient: SentryClient {
        let dsn = try! DSN("https://username:password@app.getsentry.com/12345")
        #if swift(>=3.0)
            let client = SentryClient(dsn: dsn, requestManager: MockRequestManager(session: URLSession(configuration: URLSessionConfiguration.ephemeral)))
        #else
            let client = SentryClient(dsn: dsn, requestManager: MockRequestManager(session: NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())))
        #endif
        SentryClient.shared = client
        return client
    }
    
    static let demoFatalEvent = Event.build("FATAL - A bad thing happened", build: {
        $0.level = .Fatal
        $0.tags = ["doot": "doot"]
    })
    
    private func getJSONCrashFileFromPath(path: String) -> JSONCrashFile? {
        #if swift(>=3.0)
            do {
                let data = try NSData(contentsOf: NSURL(fileURLWithPath: path) as URL, options: NSData.ReadingOptions.mappedIfSafe)
                let json = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions())
                return json as? JSONCrashFile
            } catch {
                return nil
            }
        #else
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
                return json as? JSONCrashFile
            } catch {
                return nil
            }
        #endif
    }
    
    #if !swift(>=3.0)
    func readIOSJSONCrashFile(name name: String) -> JSONCrashFile? {
        let bundle = NSBundle(forClass: self.dynamicType)
        guard let path = bundle.pathForResource(name, ofType: "json", inDirectory: "crashReports/ios-simulator-debug/") else {
            return nil
        }
        return getJSONCrashFileFromPath(path)
    }
    #endif
    
    #if swift(>=3.0)
    func readIOSJSONCrashFile(name: String) -> JSONCrashFile? {
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: name, ofType: "json", inDirectory: "crashReports/ios-simulator-debug/") else {
            return nil
        }
        return getJSONCrashFileFromPath(path: path)
    }
    #endif
    
    #if swift(>=3.0)
    func readJSONCrashFile(name: String) -> JSONCrashFile? {
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: name, ofType: "json") else {
            return nil
        }
        return getJSONCrashFileFromPath(path: path)
    }
    #endif
    
    #if !swift(>=3.0)
    func readJSONCrashFile(name name: String) -> JSONCrashFile? {
        let bundle = NSBundle(forClass: self.dynamicType)
        guard let path = bundle.pathForResource(name, ofType: "json") else {
            return nil
        }
        return getJSONCrashFileFromPath(path)
    }
    #endif
    
}
