import Foundation

/// Information about a release version returned from the update check API.
public struct ReleaseInfo: Decodable, Sendable {
  /// Unique identifier for the release
  public let id: String
  /// Build version string (e.g., "1.2.3")
  public let buildVersion: String
  /// Build number (e.g., 123)
  public let buildNumber: Int
  /// Optional release notes describing changes
  public let releaseNotes: String?
  /// URL to download the IPA file
  public let downloadUrl: String
  /// Optional URL to the app icon
  public let iconUrl: String?
  /// Display name of the app
  public let appName: String
  /// Install groups of the app
  public let installGroups: [String]?
  private let createdDate: String

  /// Parsed creation date from the server response
  public var created: Date? {
    Date.fromString(createdDate)
  }
}
