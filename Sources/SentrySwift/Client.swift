//
//  Client.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 03/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

import Foundation
import Sentry

public final class Client {

    internal let sentryClient: SentryClient

    public static var sharedClient: Client?

    internal init(_ sentryClient: SentryClient) {
        self.sentryClient = sentryClient
    }

    public convenience init(dsn: String) throws {
        var error: NSError?
        let sentryClient = SentryClient(dsn: dsn, didFailWithError: &error)
        if let actualError = error {
            throw actualError
        }
        self.init(sentryClient)
    }
    
    public func startCrashHandler() throws {
        try sentryClient.startCrashHandler()
    }

}
