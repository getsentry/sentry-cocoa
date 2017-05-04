import Foundation

extension SentryEndpoint {
	internal func configureStoreRequestData(_ data: NSData, request: NSMutableURLRequest) {
		#if swift(>=3.0)
			request.httpBody = data as Data
		#else
			request.HTTPBody = data
		#endif
	}
}
