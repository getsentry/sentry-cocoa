//
//  NSNumber+Extras.swift
//  Sentry
//
//  Created by David Chavez on 1/27/17.
//
//

import Foundation

extension NSNumber {
    var isBool: Bool {
        #if swift(>=3.0)
        return type(of: self) == type(of: NSNumber(value: true))
        #else
        return CFBooleanGetTypeID() == CFGetTypeID(self)
        #endif
    }
}
