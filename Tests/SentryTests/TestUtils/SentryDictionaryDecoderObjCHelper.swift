#if SWIFT_PACKAGE
@testable import SentrySwift
#else
@testable import Sentry
#endif
import Foundation

// A separate Swift support target lets Objective-C tests call internal Swift APIs without
// depending on the Swift test bundle (which itself depends on Objective-C test helpers).
@objc(SentryDictionaryDecoderObjCHelper)
public final class SentryDictionaryDecoderObjCHelper: NSObject {
    @objc(boolWithDictionary:key:)
    public static func bool(_ dictionary: NSDictionary, key: String) -> NSNumber? {
        guard let result = SentryDictionaryDecoder.bool(swiftDictionary(dictionary), key) else {
            return nil
        }
        return NSNumber(value: result)
    }

    @objc public static func isBool(_ number: NSNumber) -> Bool {
        SentryDictionaryDecoder.isBool(number)
    }

    @objc(uintWithDictionary:key:)
    public static func uint(_ dictionary: NSDictionary, key: String) -> NSNumber? {
        guard let result = SentryDictionaryDecoder.uint(swiftDictionary(dictionary), key) else {
            return nil
        }
        return NSNumber(value: result)
    }

    @objc(dictionaryWithDictionary:key:)
    public static func dictionary(_ dictionary: NSDictionary, key: String) -> NSDictionary? {
        guard let result = SentryDictionaryDecoder.dictionary(swiftDictionary(dictionary), key) else {
            return nil
        }
        return result as NSDictionary
    }

    @objc(stringsWithDictionary:key:)
    public static func strings(_ dictionary: NSDictionary, key: String) -> NSArray? {
        guard let result = SentryDictionaryDecoder.strings(swiftDictionary(dictionary), key) else {
            return nil
        }
        return result as NSArray
    }

    private static func swiftDictionary(_ dictionary: NSDictionary) -> [String: Any] {
        dictionary as? [String: Any] ?? [:]
    }
}
