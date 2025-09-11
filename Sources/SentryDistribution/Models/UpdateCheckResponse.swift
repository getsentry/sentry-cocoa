import Foundation

public struct UpdateCheckResponse: Decodable {
  public let current: ReleaseInfo?
  public let update: ReleaseInfo?
}
