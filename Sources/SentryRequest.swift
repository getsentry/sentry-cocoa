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
	
	internal typealias EventFinishedSending = (_ success: Bool) -> ()
	
	/*
	Sends given event to the API
	- Parameter event: An event
	- Parameter finished: A closure with the success status
	*/
	internal func sendEvent(event: Event, finished: EventFinishedSending? = nil) {
		if JSONSerialization.isValidJSONObject(event.serialized) {
			do {
                let data: Data = try JSONSerialization.data(withJSONObject: event.serialized, options: [])
				sendData(data: data, finished: finished)
			} catch {}
		}
	}
	
	/*
	Sends given data to the API
	- Parameter data: The data
	- Parameter finished: A closure with the success status
	*/
	func sendData(data: Data, finished: EventFinishedSending? = nil) {
		if let body = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue) {
			SentryLog.Debug.log(message: "body = \(body)")
		}
		
		// Creating the request and attempting to gzip
		let request: NSMutableURLRequest = NSMutableURLRequest(url: dsn.serverURL as URL)
		request.httpMethod = "POST"
		do {
            request.httpBody = try (data as NSData).gzipped(withCompressionLevel: -1)
		} catch {
			SentryLog.Error.log(message: "Failed to gzip request data = \(error)")
			request.httpBody = data
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
				SentryLog.Debug.log(message: "status = \(response.statusCode)")
				SentryLog.Debug.log(message: "response = \(NSString(data: data, encoding: String.Encoding.utf8.rawValue))")
				
				success = 200..<300 ~= response.statusCode
			}
			if let error = error {
				SentryLog.Error.log(message: "error = \(error)")

				success = false
			}
			
			finished?(success)
		}

		task.resume()
	}
}
