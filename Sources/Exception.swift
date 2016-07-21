//
//  Exception.swift
//  SentrySwift
//
// Created by David Chavez on 25/05/16.
//
//

import Foundation

// A class used to represent an exception: `sentry.interfaces.exception`
@objc public class Exception: NSObject {
    public let type: String
    public let value: String
    public var module: String?

    /// Creates `Exception` object
    @objc public init(type: String, value: String, module: String? = nil) {
        self.type = type
        self.value = value
        self.module = module

        super.init()
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        let lhs = self
        guard let rhs = object as? Exception else { return false }
        return lhs.type == rhs.type && lhs.value == rhs.value && lhs.module == rhs.module
    }
}

extension Exception: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        return [
            "type": type,
            "value": value,
        ]
        .set("module", value: module)
    }
}
