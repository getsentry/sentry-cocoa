//
//  SentryEndpoint.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 16/11/16.
//
//

import Foundation
import KSCrash.NSData_GZip

typealias SentryEndpointRequestFinished = (Bool) -> ()

enum HttpMethod: String {
    case post = "POST"
    case get = "GET"
}

protocol Endpoint {
    var httpMethod: HttpMethod { get }
    func route(dsn dsn: DSN) -> NSURL?
    var payload: NSData { get }
    func send(dsn: DSN, finished: SentryEndpointRequestFinished?)
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
    
    func route(dsn dsn: DSN) -> NSURL? {
        let components = NSURLComponents()
        components.scheme = dsn.url.scheme
        components.host = dsn.url.host
        components.port = dsn.url.port
        
        switch self {
        case .store(_), .storeSavedEvent(_):
            components.path = "/api/\(dsn.projectID)/store/"
        case .userFeedback(let userFeedback):
            components.path = "/api/embed/error-page/"
            components.queryItems = userFeedback.queryItems
            components.queryItems?.append(URLQueryItem(name: "dsn", value: dsn.url.absoluteString))
        }
        
        #if swift(>=3.0)
            return components.url as NSURL?
        #else
            return components.URL
        #endif
    }
    
    var payload: NSData {
        switch self {
        case .store(let event):
            guard JSONSerialization.isValidJSONObject(event.serialized) else {
                SentryLog.Error.log("Could not serialized event")
                return NSData()
            }
            do {
                var eventToSend = event
                if let transform = SentryClient.shared?.beforeSendEventBlock {
                    transform(&eventToSend)
                }
                #if swift(>=3.0)
                    return try JSONSerialization.data(withJSONObject: eventToSend.serialized, options: []) as NSData
                #else
                    return try JSONSerialization.dataWithJSONObject(eventToSend.serialized, options: [])
                #endif
            } catch {
                SentryLog.Error.log("Could not serialized event - \(error)")
                return NSData()
            }
        case .storeSavedEvent(let savedEvent):
            return savedEvent.data
        case .userFeedback(let userFeedback):
            guard let data = userFeedback.serialized else {
                SentryLog.Error.log("Could not serialize userFeedback")
                return NSData()
            }
            return data as NSData
        }
    }
    
    func configureRequest(dsn dsn: DSN, request: NSMutableURLRequest) {
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
                    request.httpBody = try data.gzipped(withCompressionLevel: -1)
                #else
                    request.HTTPBody = try data.gzippedWithCompressionLevel(-1)
                #endif
                request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            } catch {
                SentryLog.Error.log("Failed to gzip request data = \(error)")
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
    
    func send(dsn: DSN, finished: SentryEndpointRequestFinished? = nil) {
        guard let url = route(dsn: dsn) else {
            SentryLog.Error.log("Cannot find route for \(self)")
            finished?(false)
            return
        }
        
        #if swift(>=3.0)
            let request: NSMutableURLRequest = NSMutableURLRequest(url: url as URL)
        #else
            let request: NSMutableURLRequest = NSMutableURLRequest(URL: url)
        #endif
        
        configureRequest(dsn: dsn, request: request)
        
        #if swift(>=3.0)
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            session.dataTask(with: request as URLRequest) { data, response, error in
                var success = false
                
                // Returns success if we have data and 200 response code
                if let data = data, let response = response as? HTTPURLResponse {
                    SentryLog.Debug.log("status = \(response.statusCode)")
                    SentryLog.Debug.log("response = \(NSString(data: data, encoding: String.Encoding.utf8.rawValue))")
                    
                    success = 200..<300 ~= response.statusCode
                }
                if let error = error {
                    SentryLog.Error.log("error = \(error)")
                    
                    success = false
                }
                
                finished?(success)
            }.resume()
        #else
            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
            let session = NSURLSession(configuration: config)
            session.dataTaskWithRequest(request) { data, response, error in
                var success = false
            
                // Returns success if we have data and 200 response code
                if let data = data, let response = response as? NSHTTPURLResponse {
                    SentryLog.Debug.log("status = \(response.statusCode)")
                    SentryLog.Debug.log("response = \(NSString(data: data, encoding: NSUTF8StringEncoding))")
            
                    success = 200..<300 ~= response.statusCode
                }
                if let error = error {
                    SentryLog.Error.log("error = \(error)")
            
                    success = false
                }
            
                finished?(success)
            }.resume()
        #endif
    }
    
    private func debugData(_ data: NSData) {
        #if swift(>=3.0)
            guard let body = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue) else {
                return
            }
        #else
            guard let body = NSString(data: data, encoding: NSUTF8StringEncoding) else {
                return
            }
        #endif
        SentryLog.Debug.log("body = \(body)")
    }
}
