// swiftlint:disable missing_docs
import Foundation

private let levelNames = ["none", "debug", "info", "warning", "error", "fatal"]

#if SWIFT_PACKAGE
extension SentryLevel: @retroactive CustomStringConvertible {}
#else
extension SentryLevel: CustomStringConvertible {}
#endif

extension SentryLevel {
    public var description: String {
        return levelNames[Int(self.rawValue)]
    }

    static func fromName(_ name: String?) -> SentryLevel? {
        guard let name,
              let index = levelNames.firstIndex(of: name),
              let level = SentryLevel(rawValue: UInt(index)) else {
            return nil
        }
        return level
    }
}

@objcMembers
@_spi(Private) public final class SentryLevelHelper: NSObject {
    public static func nameForLevel(_  level: SentryLevel) -> String {
        return level.description
    }
    
    public static func levelForName(_ name: String?) -> SentryLevel {
        .fromName(name) ?? .error
    }
}
// swiftlint:enable missing_docs
