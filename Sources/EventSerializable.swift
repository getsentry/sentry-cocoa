//
//  EventSerializable.swift
//  SentrySwift
//
//  Created by Josh Holtz on 12/22/15.
//
//

import Foundation

internal typealias SerializedTypeDictionary = [String: AnyType]
internal typealias SerializedTypeArray = [SerializedTypeDictionary]
internal typealias Attribute = (key: String, value: AnyType?)

/// A protocol used for complex structures (ex: Event, User)
/// on how to serialize them.
internal protocol EventSerializable {
    associatedtype SerializedType
    var serialized: SerializedType { get }
}

internal func convertAttributes(_ attributes: [Attribute]) -> SerializedTypeDictionary {
    var ret: SerializedTypeDictionary = [:]
    attributes.filter() { $0.value != nil }.forEach() { ret.updateValue($0.value!, forKey: $0.key) }
    return ret
}
