//
//  RequestManager.swift
//  Sentry
//
//  Created by Daniel Griesser on 21/12/2016.
//
//

import Foundation

protocol RequestManager {
    init(session: URLSession)
    func addRequest(_ request: URLRequest, finished: SentryEndpointRequestFinished?)
    var isReady: Bool { get }
}
