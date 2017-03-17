import Vapor
import Sentry

import Foundation

public final class Provider: Vapor.Provider {
	
	public convenience init(config: Config) throws {
		guard let vaporSentry = config["sentry"]?.object else {
			throw SentryProviderError.config("no sentry.json config file")
		}
		guard let dsn = vaporSentry["dsn"]?.string else {
			throw SentryProviderError.config("No 'dsn' key in sentry.json config file.")
		}
		
		switch vaporSentry["log_level"]?.string {
		case "error"?:
			SentryClient.logLevel = .Error
		case "debug"?:
			SentryClient.logLevel = .Debug
		case "verbose"?:
			SentryClient.logLevel = .Verbose
		default:
			SentryClient.logLevel = .None
		}
		
		SentryClient.shared = SentryClient(dsnString: dsn)
		
		try self.init()
	}
	
	public init() throws {

	}
	
	public func beforeRun(_: Droplet) {
		
	}
	
	public func afterInit(_ drop: Droplet) {
		drop.storage["sentry_client"] = SentryClient.shared
	}
	
	public enum SentryProviderError: Swift.Error {
		case config(String)
	}
}
