import Foundation

/// Utility class for locale-related functionality.
@_spi(Private) @objcMembers
public class SentryLocale: NSObject {

    /// Determines if the current locale uses 24-hour time format.
    /// - Returns: `true` if 24-hour format is used, `false` if 12-hour (AM/PM) format is used.
    public static func timeIs24HourFormat() -> Bool {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let dateString = formatter.string(from: Date())
        let amRange = dateString.range(of: formatter.amSymbol)
        let pmRange = dateString.range(of: formatter.pmSymbol)
        return amRange == nil && pmRange == nil
    }

    /// Determines if the current locale's language is a right-to-left language.
    /// - Returns: `true` if the language is RTL, `false` otherwise.
    public static func isRightToLeftLanguage() -> Bool {
        let languageCode: String?
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, visionOS 1, *) {
            languageCode = Locale.current.language.languageCode?.identifier
        } else {
            languageCode = Locale.current.languageCode
        }
        guard let languageCode else {
            return false
        }
        return NSLocale.characterDirection(forLanguage: languageCode) == .rightToLeft
    }
}
