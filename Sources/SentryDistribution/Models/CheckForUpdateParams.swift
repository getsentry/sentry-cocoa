import Foundation

/// A model for configuring parameters needed to check for app updates.
public struct CheckForUpdateParams {
  /// Creates a new instance with the required parameters for update checking.
  /// - Parameters:
  ///   - accessToken: Bearer token for authentication with Sentry API
  ///   - organization: Sentry organization slug
  ///   - project: Sentry project slug
  ///   - hostname: Sentry hostname (defaults to "us.sentry.io")
  ///   - binaryIdentifierOverride: Optional UUID override for the main binary
  ///   - appIdOverride: Optional bundle identifier override
  ///   - installGroupsOverride: Optional override of the install groups
  public init(
    accessToken: String,
    organization: String,
    project: String,
    hostname: String = "us.sentry.io",
    binaryIdentifierOverride: String? = nil,
    appIdOverride: String? = nil,
    installGroupsOverride: [String]? = nil) {
    self.accessToken = accessToken
    self.organization = organization
    self.project = project
    self.hostname = hostname
    self.binaryIdentifierOverride = binaryIdentifierOverride
    self.appIdOverride = appIdOverride
    self.installGroupsOverride = installGroupsOverride
  }

  let accessToken: String
  let organization: String
  let project: String
  let hostname: String
  let binaryIdentifierOverride: String?
  let appIdOverride: String?
  let installGroupsOverride: [String]?
}
