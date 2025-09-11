import Foundation

extension Date {
  static func fromString(_ input: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [ .withInternetDateTime, .withFractionalSeconds ]
    return formatter.date(from: input)
  }
}
