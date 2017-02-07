//
//  EventProperties.swift
//  Sentry
//
//  Created by Josh Holtz on 2/1/16.
//
//

import Foundation

/// Protocol defining common editable properties of Sentry client and Event
internal protocol EventProperties {
    // MARK: - Attributes
    var releaseVersion: String? { get set }
    var buildNumber: String? { get set }
    var tags: EventTags { get set }
    var extra: EventExtra { get set }
    
    // MARK: - Interfaces
    var user: User? { get set }
}

@objc public protocol EventPropertiesSetter {
    func addExtra(_ key: String, value: AnyType)
    func addTag(_ key: String, value: String)
    var extra: EventExtra { get set }
    var tags: EventTags { get set }
}

// Sadly we have to do it like this because procotol extensions do not work in objc
extension Event: EventPropertiesSetter {
    @objc public func addExtra(_ key: String, value: AnyType) {
        extra = extra.set(key, value: value)
    }
    @objc public func addTag(_ key: String, value: String) {
        tags = tags.set(key, value: value)
    }
}

extension SentryClient: EventPropertiesSetter {
    @objc public func addExtra(_ key: String, value: AnyType) {
        extra = extra.set(key, value: value)
    }
    @objc public func addTag(_ key: String, value: String) {
        tags = tags.set(key, value: value)
    }
}
