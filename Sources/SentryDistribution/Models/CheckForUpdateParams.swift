import Foundation

/// A model for configuring parameters needed to check for app updates.
public struct CheckForUpdateParams {
  public init(accessToken: String, organization: String, project: String, hostname: String = "us.sentry.io", binaryIdentifierOverride: String? = nil, appIdOverride: String? = nil) {
    self.accessToken = accessToken
    self.organization = organization
    self.project = project
    self.hostname = hostname
    self.binaryIdentifierOverride = binaryIdentifierOverride
    self.appIdOverride = appIdOverride
  }

  let accessToken: String
  let organization: String
  let project: String
  let hostname: String
  let binaryIdentifierOverride: String?
  let appIdOverride: String?
}
