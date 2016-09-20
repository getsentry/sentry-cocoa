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

/// A protocol used for complex structures (ex: Event, User, AppleCrashReport)
/// on how to serialize them.
internal protocol EventSerializable {
	associatedtype SerializedType
	var serialized: SerializedType { get }
}
