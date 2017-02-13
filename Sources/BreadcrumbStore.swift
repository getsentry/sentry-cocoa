//
//  BreadcrumbStore.swift
//  Sentry
//
//  Created by Josh Holtz on 3/29/16.
//
//

import Foundation

/// A class used to hold and store our `Breadcrumb`
@objc public final class BreadcrumbStore: NSObject {
    
    public typealias StoreUpdated = (BreadcrumbStore) -> Void
    
    // MARK: - Attributes
    
    private(set) var crumbs: [Breadcrumb] = []
    
    private var _maxCrumbs: Int = 50
    public var maxCrumbs: Int {
        get { return _maxCrumbs }
        set { _maxCrumbs = max(0, newValue) }
    }
    
    internal var storeUpdated: StoreUpdated?
    
    // MARK: - Public Interface
    
    /// Adds given crumb to the client store
    public func add(_ crumb: Breadcrumb) {
        Log.Debug.log("Added breadcrumb: \(crumb.category) \(crumb.type) \(crumb.message)")
        if crumbs.count >= maxCrumbs {
            crumbs.removeFirst()
        }
        
        crumbs.append(crumb)
        storeUpdated?(self)
    }
    
    /// Clears the store if crumbs exist
    public func clear() {
        guard !crumbs.isEmpty else { return }
        crumbs.removeAll()
        storeUpdated?(self)
    }
}

extension BreadcrumbStore: EventSerializable {
    internal typealias SerializedType = SerializedTypeArray
    internal var serialized: SerializedType {
        return crumbs.map { $0.serialized }.flatMap { $0 }
    }
}
