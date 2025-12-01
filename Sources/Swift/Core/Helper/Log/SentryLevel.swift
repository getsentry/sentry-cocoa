import Foundation

private let levelNames = ["none", "debug", "info", "warning", "error", "fatal"]

extension SentryLevel: CustomStringConvertible { 
    public var description: String {
        return levelNames[Int(self.rawValue)]
    }
    
    static func fromName(_ name: String?) -> SentryLevel {
        guard let name = name, let index = levelNames.firstIndex(of: name) else { return .error }
        return SentryLevel(rawValue: UInt(index)) ?? .error
    }
}

@objcMembers
@_spi(Private) public class SentryLevelHelper: NSObject {
    public static func nameForLevel(_  level: SentryLevel) -> String {
        return level.description
    }
    
    public static func levelForName(_ name: String?) -> SentryLevel {
        .fromName(name)
    }
}
