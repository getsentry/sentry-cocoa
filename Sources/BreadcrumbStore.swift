//
//  BreadcrumbStore.swift
//  SentrySwift
//
//  Created by Josh Holtz on 3/29/16.
//
//

import Foundation

@objc public class BreadcrumbStore: NSObject {
	
	private var crumbs = [String: [Breadcrumb]]()
	
	private var _maxCrumbsForType = 20
	public var maxCrumbsForType: Int {
		get { return _maxCrumbsForType }
		set { _maxCrumbsForType = max(0, newValue) }
	}
	
	public typealias StoreUpdated = (BreadcrumbStore) -> ()
	public var storeUpdated: StoreUpdated?
	
	public func add(crumb: Breadcrumb) {
		var typedCrumbs = crumbs[crumb.type] ?? []
		typedCrumbs.insert(crumb, atIndex: 0)
		
		if typedCrumbs.count > maxCrumbsForType {
			typedCrumbs = Array(typedCrumbs[0..<maxCrumbsForType])
		}
		
		crumbs[crumb.type] = typedCrumbs
		storeUpdated?(self)
	}
	
	public func get(type: String) -> [Breadcrumb]? {
		return crumbs[type]
	}
	
	public func clear(type: String? = nil) {
		if let type = type {
			crumbs.removeValueForKey(type)
		} else {
			crumbs.removeAll()
		}
		storeUpdated?(self)
	}
	
}

extension BreadcrumbStore: EventSerializable {
	public typealias SerializedType = SerializedTypeArray
	public var serialized: SerializedType {
		return crumbs.values.flatMap{$0.map{$0.serialized}}.flatMap{$0}
	}
}
