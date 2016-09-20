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
    public var extra: [String: AnyType]

    /// Creates a user
    /// - Parameter userID: A user id
    /// - Parameter email: An optional email
    /// - Parameter username: An optional username
    /// - Parameter extra: An optional extra dictionary
    @objc public init(id userID: String, email: String? = nil, username: String? = nil, extra: [String: AnyType] = [:]) {
        self.userID = userID
        self.email = email
        self.username = username
        self.extra = extra

        super.init()
    }

    /// Creates a user from a dictionary
    /// This will mostly get used from a saved offline event
    /// - Parameter dictionary: A dictionary of data to parse to fill properties of a user
    internal convenience init?(dictionary: [String: AnyType]?) {
        guard let dictionary = dictionary, let userID = dictionary["id"] as? String else { return nil }
        self.init(
        id: userID,
                email: dictionary["email"] as? String,
                username: dictionary["username"] as? String,
                extra: dictionary
        )
    }
}

extension User: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        return extra
            .set("id", value: userID)
            .set("email", value: email)
            .set("username", value: username)
    }
}
