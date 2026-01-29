import Foundation

/// A custom byte count formatter that provides locale-independent formatting.
///
/// We need to have a standard description for byte counts but NSByteCountFormatter
/// does not allow choosing a locale, and the result changes according to the device
/// configuration. With our own formatter we can control the result.
@_spi(Private) @objcMembers
public class SentryByteCountFormatter: NSObject {

    /// Returns a human-readable string representation of the given byte count.
    /// - Parameter bytes: The number of bytes to format.
    /// - Returns: A formatted string like "1,024 KB" or "512 MB".
    public static func bytesCountDescription(_ bytes: UInt) -> String {
        let units = ["bytes", "KB", "MB", "GB"]
        var index = 0
        var result = Double(bytes)

        while result >= 1_024 && index < units.count - 1 {
            result /= 1_024.0
            index += 1
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.roundingMode = .floor
        formatter.positiveFormat = "#,##0"

        let formattedNumber = formatter.string(from: NSNumber(value: result)) ?? "\(Int(result))"
        return "\(formattedNumber) \(units[index])"
    }
}
