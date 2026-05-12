@_implementationOnly import _SentryPrivate
import Foundation

private let maxSanitizeDepth: UInt = 200

/// Recursively sanitizes an NSDictionary, converting non-serializable values to strings.
@_cdecl("sentry_sanitize_dictionary")
public func sentry_sanitize_dictionary(_ dictionary: NSDictionary?) -> NSDictionary? {
    sanitizeDictionary(dictionary, depth: 0)
}

private func sanitizeValue(_ rawValue: Any, depth: UInt) -> Any? {
    switch rawValue {
    case let string as String:
        return string
    case let number as NSNumber:
        return number
    case let dict as NSDictionary:
        return sanitizeDictionary(dict, depth: depth)
    case let array as NSArray:
        return sanitizeArray(array, depth: depth)
    case let date as NSDate:
        return sentry_toIso8601String(date as Date)
    default:
        return String(describing: rawValue)
    }
}

private func sanitizeDictionary(_ dictionary: NSDictionary?, depth: UInt) -> NSDictionary? {
    guard let dictionary else { return nil }
    guard type(of: dictionary).isSubclass(of: NSDictionary.self) else { return nil }
    guard depth < maxSanitizeDepth else { return nil }

    guard let dictionaryCopy = dictionary.copy() as? NSDictionary else { return nil }

    let result = NSMutableDictionary()
    for rawKey in dictionaryCopy.allKeys {
        guard let rawValue = dictionaryCopy.object(forKey: rawKey) else { continue }

        let stringKey = (rawKey as? String) ?? String(describing: rawKey)

        if stringKey.hasPrefix("__sentry") {
            continue
        }

        result.setValue(sanitizeValue(rawValue, depth: depth + 1), forKey: stringKey)
    }
    return result
}

private func sanitizeArray(_ array: NSArray, depth: UInt) -> NSArray {
    guard type(of: array).isSubclass(of: NSArray.self) else { return NSArray() }
    guard depth < maxSanitizeDepth else { return NSArray() }

    guard let arrayCopy = array.copy() as? NSArray else { return NSArray() }

    let result = NSMutableArray()
    for rawValue in arrayCopy {
        guard let sanitized = sanitizeValue(rawValue, depth: depth + 1) else { continue }
        result.add(sanitized)
    }
    return result
}
