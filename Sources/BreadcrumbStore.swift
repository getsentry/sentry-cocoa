//
//  BreadcrumbStore.swift
//  SentrySwift
//
//  Created by Josh Holtz on 3/29/16.
//
//

import Foundation

/// A class used to hold and store our `Breadcrumb`
public class BreadcrumbStore: NSObject {

	public typealias StoreUpdated = (BreadcrumbStore) -> ()

	// MARK: - Attributes

	private(set) var crumbs: [Breadcrumb] = []

	private var _maxCrumbs: Int = 20
	internal var maxCrumbs: Int {
		get { return _maxCrumbs }
		set { _maxCrumbs = max(0, newValue) }
	}

	internal var storeUpdated: StoreUpdated?


	// MARK: - Public Interface

	/// Adds given crumb to the client store
	public func add(_ crumb: Breadcrumb) {
		if crumbs.count >= maxCrumbs {
			crumbs.removeFirst()
		}

		crumbs.append(crumb)
		storeUpdated?(self)
	}

	/// Clears the store for given type or all if none specified
	public func clear() {
		crumbs.removeAll()
		storeUpdated?(self)
	}
}

extension BreadcrumbStore: EventSerializable {
	internal typealias SerializedType = SerializedTypeArray
	internal var serialized: SerializedType {
		return crumbs.map{$0.serialized}.flatMap{$0}
	}
}
