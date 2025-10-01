import Foundation

/// Response from the update check API containing current and available release information.
public struct UpdateCheckResponse: Decodable, Sendable {
  /// Information about the currently installed release
  public let current: ReleaseInfo?
  /// Information about the available update (nil if no update available)
  public let update: ReleaseInfo?
}
