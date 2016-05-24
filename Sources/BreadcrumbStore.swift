//
//  BreadcrumbStore.swift
//  SentrySwift
//
//  Created by Josh Holtz on 3/29/16.
//
//

import Foundation

@objc public class BreadcrumbStore: NSObject {
	
	private var crumbs = [Breadcrumb]()
	
	private var _maxCrumbs = 20
	public var maxCrumbs: Int {
		get { return _maxCrumbs }
		set { _maxCrumbs = max(0, newValue) }
	}
	
	public typealias StoreUpdated = (BreadcrumbStore) -> ()
	public var storeUpdated: StoreUpdated?
	
	public func add(crumb: Breadcrumb) {
		
		if crumbs.count >= maxCrumbs {
			crumbs.removeFirst()
		}
		crumbs.append(crumb)
		
		storeUpdated?(self)
	}
	
	public func get() -> [Breadcrumb]? {
		return crumbs
	}
	
	public func clear() {
		crumbs.removeAll()
		storeUpdated?(self)
	}
	
}

extension BreadcrumbStore: EventSerializable {
	public typealias SerializedType = SerializedTypeArray
	public var serialized: SerializedType {
		return crumbs.map{$0.serialized}.flatMap{$0}
	}
}
