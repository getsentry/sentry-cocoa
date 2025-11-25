import Foundation

extension Date {
  static let formatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    return formatter
  }()

  static func fromString(_ input: String) -> Date? {
    return formatter.date(from: input)
  }
}
