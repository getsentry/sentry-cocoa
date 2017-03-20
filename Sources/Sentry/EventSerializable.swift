//
//  EventSerializable.swift
//  Sentry
//
//  Created by Josh Holtz on 12/22/15.
//
//

import Foundation

public typealias SerializedTypeDictionary = [String: AnyType]
public typealias SerializedTypeArray = [SerializedTypeDictionary]
public typealias Attribute = (key: String, value: AnyType?)

/// A protocol used for complex structures (ex: Event, User)
/// on how to serialize them.
public protocol EventSerializable {
    associatedtype SerializedType
    var serialized: SerializedType { get }
}

func convertAttributes(_ attributes: [Attribute]) -> SerializedTypeDictionary {
    var ret: SerializedTypeDictionary = [:]
    attributes.filter {
        $0.value != nil
    }.forEach {
        guard let value = $0.value else { return }
        ret.updateValue(value, forKey: $0.key)
    }
    return ret
}
