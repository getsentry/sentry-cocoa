import Vapor
import HTTP
import Sentry

import Foundation

public final class Middleware: HTTP.Middleware {
	
	let levels: [Int: Sentry.Severity]
	
	public init(levels: [Int: Sentry.Severity] = [500: .Error]) {
		self.levels = levels
	}
	
	public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
	
		// 1. Attempts to process the request
		// 2. If error, processes error to Sentry
		// 3. Rethrows errors
		do {
			let response = try next.respond(to: request)
			return response
		} catch let error as Abort {
			
			// Only sends to Sentry if the status code
			// is configured to
			if let severity = levels[error.status.statusCode] {
				let status = error.status.statusCode
				let method = request.method.description
				let uri = request.uri.description
				
				let message = "[\(status)] \(method) - \(uri)"
				
				SentryClient.shared?.captureMessage(message, level: severity)
			}
			
			throw error
		} catch {
			throw error
		}
	}
}
