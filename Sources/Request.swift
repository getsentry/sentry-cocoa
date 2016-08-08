//
//  Request.swift
//  SentrySwift
//
//  Created by Josh Holtz on 1/7/16.
//
//

import Foundation

import KSCrash.NSData_GZip

extension SentryClient {
	
	internal typealias EventFinishedSending = (success: Bool) -> ()
	
	/*
	Sends given event to the API
	- Parameter event: An event
	- Parameter finished: A closure with the success status
	*/
	internal func sendEvent(event: Event, finished: EventFinishedSending? = nil) {
		if NSJSONSerialization.isValidJSONObject(event.serialized) {
			do {
				let data: NSData = try NSJSONSerialization.dataWithJSONObject(event.serialized, options: [])
				sendData(data, finished: finished)
			} catch {
				SentryLog.Error.log("Could not serialized event - \(error)")
			}
		} else {
			SentryLog.Error.log("Could not serialized event")
		}
	}
	
	/*
	Sends given data to the API
	- Parameter data: The data
	- Parameter finished: A closure with the success status
	*/
	func sendData(data: NSData, finished: EventFinishedSending? = nil) {
		if let body = NSString(data: data, encoding: NSUTF8StringEncoding) {
			SentryLog.Debug.log("body = \(body)")
		}
		
		// Creating the request and attempting to gzip
		let request: NSMutableURLRequest = NSMutableURLRequest(URL: dsn.serverURL)
		request.HTTPMethod = "POST"
		do {
			request.HTTPBody = try data.gzippedWithCompressionLevel(-1)
		} catch {
			SentryLog.Error.log("Failed to gzip request data = \(error)")
			request.HTTPBody = data
		}
		
		// Setting the headers
		let sentryHeader = dsn.xSentryAuthHeader
		request.setValue(sentryHeader.value, forHTTPHeaderField: sentryHeader.key)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
		
		// Creating data task
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		let session = NSURLSession(configuration: config)
		
		// Creates and starts network request
		let task: NSURLSessionDataTask = session.dataTaskWithRequest(request) { data, response, error in
			var success = false
			
			// Returns success if we have data and 200 response code
			if let data = data, response = response as? NSHTTPURLResponse {
				SentryLog.Debug.log("status = \(response.statusCode)")
				SentryLog.Debug.log("response = \(NSString(data: data, encoding: NSUTF8StringEncoding))")
				
				success = 200..<300 ~= response.statusCode
			}
			if let error = error {
				SentryLog.Error.log("error = \(error)")

				success = false
			}
			
			finished?(success: success)
		}

		task.resume()
	}
}
