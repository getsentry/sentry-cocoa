//
//  SentryEndpoint.swift
//  Sentry
//
//  Created by Daniel Griesser on 16/11/16.
//
//

import Foundation
import KSCrash.NSData_GZip

internal typealias SentryEndpointRequestFinished = (Bool) -> Void

enum HttpMethod: String {
    case post = "POST"
    case get = "GET"
}

protocol Endpoint {
    var httpMethod: HttpMethod { get }
    var payload: Data { get }
    func send(requestManager: RequestManager, dsn: DSN, finished: SentryEndpointRequestFinished?)
    func routeForDsn(_ dsn: DSN) -> URL?
}

enum SentryEndpoint: Endpoint {
    
    case store(event: Event)
    case storeSavedEvent(event: SavedEvent)
    case userFeedback(userFeedback: UserFeedback)
    
    var httpMethod: HttpMethod {
        switch self {
        case .store(_), .storeSavedEvent(_), .userFeedback(_):
            return .post
        }
    }
    
    var payload: Data {
        switch self {
        case .store(let event):
            do {
                var eventToSend = event
                if let transform = SentryClient.shared?.beforeSendEventBlock {
                    transform(&eventToSend)
                }
                // Not very happy with this solution
                if let transform = SentryClient.shared?.objcBeforeSendEventBlock {
                    transform(&eventToSend)
                }
                let serializedEvent = eventToSend.serialized
                guard JSONSerialization.isValidJSONObject(serializedEvent) else {
                    Log.Error.log("Could not serialized event")
                    return Data()
                }
                #if swift(>=3.0)
                    return try JSONSerialization.data(withJSONObject: serializedEvent, options: [])
                #else
                    return try JSONSerialization.dataWithJSONObject(serializedEvent, options: [])
                #endif
            } catch {
                Log.Error.log("Could not serialized event - \(error)")
                return Data()
            }
        case .storeSavedEvent(let savedEvent):
            return savedEvent.data
        case .userFeedback(let userFeedback):
            guard let data = userFeedback.serialized else {
                Log.Error.log("Could not serialize userFeedback")
                return Data()
            }
            return data
        }
    }
    
    func send(requestManager: RequestManager, dsn: DSN, finished: SentryEndpointRequestFinished? = nil) {
        guard let url = routeForDsn(dsn) else {
            Log.Error.log("Cannot find route for \(self)")
            finished?(false)
            return
        }
        
        #if swift(>=3.0)
            let request: NSMutableURLRequest = NSMutableURLRequest(url: url)
        #else
            let request: NSMutableURLRequest = NSMutableURLRequest(URL: url)
        #endif
        
        configureRequestWithDsn(dsn, request: request)
        
        requestManager.addRequest(request as URLRequest, finished: finished)
    }
    
    func routeForDsn(_ dsn: DSN) -> URL? {
        var components = URLComponents()
        components.scheme = dsn.url.scheme
        components.host = dsn.url.host
        components.port = dsn.url.port as Int?
        
        switch self {
        case .store(_), .storeSavedEvent(_):
            components.path = "/api/\(dsn.projectID)/store/"
        case .userFeedback(let userFeedback):
            components.path = "/api/embed/error-page/"
            components.queryItems = userFeedback.queryItems
            components.queryItems?.append(URLQueryItem(name: "dsn", value: dsn.url.absoluteString))
        }
        
        #if swift(>=3.0)
            return components.url
        #else
            return components.URL
        #endif
    }
    
    private func configureRequestWithDsn(_ dsn: DSN, request: NSMutableURLRequest) {
        let sentryHeader = dsn.xSentryAuthHeader
        request.setValue(sentryHeader.value, forHTTPHeaderField: sentryHeader.key)
        
        let data = payload
        debugData(data)
        
        #if swift(>=3.0)
            request.httpMethod = httpMethod.rawValue
        #else
            request.HTTPMethod = httpMethod.rawValue
        #endif
        
        switch self {
        case .store(_), .storeSavedEvent(_):
            do {
                #if swift(>=3.0)
                    request.httpBody = try (data as NSData).gzipped(withCompressionLevel: -1)
                #else
                    request.HTTPBody = try data.gzippedWithCompressionLevel(-1)
                #endif
                request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            } catch {
                Log.Error.log("Failed to gzip request data = \(error)")
                #if swift(>=3.0)
                    request.httpBody = data as Data
                #else
                    request.HTTPBody = data
                #endif
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .userFeedback(_):
            #if swift(>=3.0)
                request.httpBody = data as Data
            #else
                request.HTTPBody = data
            #endif
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(dsn.url.absoluteString, forHTTPHeaderField: "Origin")
        }
    }
    
    private func debugData(_ data: Data) {
        #if swift(>=3.0)
            guard let body = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else {
                return
            }
        #else
            guard let body = NSString(data: data, encoding: NSUTF8StringEncoding) else {
                return
            }
        #endif
        Log.Verbose.log("body = \(body)")
    }
}
