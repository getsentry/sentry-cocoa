import Foundation

public struct ReleaseInfo: Decodable {
  public let id: String
  public let buildVersion: String
  public let buildNumber: Int
  public let releaseNotes: String?
  public let downloadUrl: String
  public let iconUrl: String?
  public let appName: String
  private let createdDate: String

  public var created: Date? {
    Date.fromString(createdDate)
  }
}
