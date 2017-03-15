//
//  Functions.swift
//  Sentry
//
//  Created by David Chavez on 1/27/17.
//
//

import Foundation

/// Sanitizes an object into a representation that can be
/// validly converted to JSON data using JSONSerialization.
///
/// - Parameter object: the object to sanitize.
/// - Returns: The nearest corellated object that can be converted to JSON. Defaults to string representation.
/// The force unwrap is there to circumvent a bug in swiftc dealing with optionals and default cases..
func sanitize(_ object: AnyType) -> AnyType {
    switch object {
    case let v as [AnyType]:
        return v.map(sanitize)
    case let v as [String: AnyType]:
        return v.map(sanitize)
    case let v as String:
        return v as String
    case let v as URL:
        let url: String! = v.absoluteString
        return url
    case let v as NSNull:
        return v
    case let v as NSNumber:
        if v.isBool {
            return v as Bool
        } else {
            return v
        }
    case let v as NSError:
        #if swift(>=3.0)
            let userInfo = sanitize(v.userInfo)
        #else
            let userInfo = (sanitize(v.userInfo) as? [NSObject: AnyObject]) ?? [:]
        #endif
        
        return [
            "domain": v.domain,
            "code": v.code,
            "user_info": userInfo
        ]
    default:
        return "\(object)"
    }
}
