@testable import SentryDistribution
import Testing

@Test func testCheckForUpdatesParamsDefaults() throws {
  let token = "token"
  let org = "org"
  let project = "project"
  let checkForUpdatesParams = CheckForUpdateParams(accessToken: token, organization: org, project: project)
  #expect(checkForUpdatesParams.accessToken == token)
  #expect(checkForUpdatesParams.organization == org)
  #expect(checkForUpdatesParams.project == project)
  #expect(checkForUpdatesParams.hostname == "us.sentry.io")
  #expect(checkForUpdatesParams.appIdOverride == nil)
  #expect(checkForUpdatesParams.binaryIdentifierOverride == nil)
}
