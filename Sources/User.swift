//
//  User.swift
//  SentrySwift
//
//  Created by Josh Holtz on 2/1/16.
//
//

import Foundation

/// A class used to represent the user attached to events
@objc public class User: NSObject {
	public var userID: String
	public var email: String?
	public var username: String?
	public var extra: [String: AnyObject]?
	
	/// Creates a user
	/// - Parameter userID: A user id
	/// - Parameter email: An optional email
	/// - Parameter username: An optional username
	/// - Parameter extra: An optional extra dictionary
	public init(id userID: String, email: String? = nil, username: String? = nil, extra: [String: AnyObject]? = nil) {
		self.userID = userID
		self.email = email
		self.username = username
		self.extra = extra
	}
	
	/// Creates a user from a dictionary
	/// This will mostly get used from a saved offline event
	/// - Parameter dictionary: A dictionary of data to parse to fill properties of a user
	public convenience init?(dictionary: [String: AnyObject]?) {
		guard let dictionary = dictionary, userID = dictionary["id"] as? String else { return nil }
		self.init(
			id: userID,
			email: dictionary["email"] as? String,
			username: dictionary["username"] as? String,
			extra: dictionary
		)
	}
}

extension User: EventSerializable {
	public typealias SerializedType = SerializedTypeDictionary
	public var serialized: SerializedType {
		var info = extra ?? [String: AnyObject]()
		info["id"] = userID
		
		if let email = email {
			info["email"] = email
		}
		if let username = username {
			info["username"] = username
		}
		
		return info
	}
}
