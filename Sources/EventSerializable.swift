//
//  EventSerializable.swift
//  SentrySwift
//
//  Created by Josh Holtz on 12/22/15.
//
//

import Foundation

public typealias SerializedTypeDictionary = [String: AnyObject]
public typealias SerializedTypeArray = [SerializedTypeDictionary]

/// A protocol used for complex structures (ex: Event, User, AppleCrashReport)
/// on how to serialize them.
public protocol EventSerializable {
	typealias SerializedType
	var serialized: SerializedType { get }
}
