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
	
	internal typealias EventFinishedSending = (Bool) -> ()
	
	/*
	Sends given event to the API
	- Parameter event: An event
	- Parameter finished: A closure with the success status
	*/
	internal func sendEvent(_ event: Event, finished: EventFinishedSending? = nil) {
		if JSONSerialization.isValidJSONObject(event.serialized) {
			do {
				#if swift(>=3.0)
					let data: NSData = try JSONSerialization.data(withJSONObject: event.serialized, options: []) as NSData
				#else
					let data: NSData = try JSONSerialization.dataWithJSONObject(event.serialized, options: [])
				#endif
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
	#if swift(>=3.0)
	func sendData(_ data: NSData, finished: EventFinishedSending? = nil) {
		if let body = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue) {
			SentryLog.Debug.log("body = \(body)")
		}
		
		// Creating the request and attempting to gzip
		let request: NSMutableURLRequest = NSMutableURLRequest(url: dsn.serverURL as URL)
		request.httpMethod = "POST"
		do {
			request.httpBody = try data.gzipped(withCompressionLevel: -1)
		} catch {
			SentryLog.Error.log("Failed to gzip request data = \(error)")
			request.httpBody = data as Data
		}
		
		// Setting the headers
		let sentryHeader = dsn.xSentryAuthHeader
		request.setValue(sentryHeader.value, forHTTPHeaderField: sentryHeader.key)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
		
		// Creating data task
		let config = URLSessionConfiguration.default
		let session = URLSession(configuration: config)
		
		// Creates and starts network request
		let task: URLSessionDataTask = session.dataTask(with: request as URLRequest) { data, response, error in
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
		}
		
		task.resume()
	}	#else
		func sendData(_ data: NSData, finished: EventFinishedSending? = nil) {
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
				
				finished?(success)
			}

			task.resume()
		}
	#endif
}
