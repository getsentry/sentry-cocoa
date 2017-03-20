import KSCrash.NSData_GZip

extension SentryEndpoint {
	internal func configureStoreRequestData(_ data: NSData, request: NSMutableURLRequest) {
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
	}
}
