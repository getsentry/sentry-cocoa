import Foundation
@testable import SentryDistribution
import Testing

@Test func testUpdaterReturnsErrorForInvalidHostname() async throws {
  let parmas = CheckForUpdateParams(accessToken: "", organization: "", project: "", hostname: "%")
  await confirmation("Receives error") { confirm in
    Updater.checkForUpdate(params: parmas) { result in
      switch result {
      case .success:
        #expect(Bool(false), "Should not be a successful response")
      case .failure(let error):
        switch error as? Error {
        case .invalidUrl:
          confirm()
        default:
          #expect(Bool(false), "Unexpected error case \(error)")
        }
      }
    }
  }
}

@Test func testSuccessfullUpdateRequest() async throws {
  let params = CheckForUpdateParams(accessToken: "token", organization: "org", project: "project")
  let configuration = URLSessionConfiguration.default
  configuration.protocolClasses = [MockURLProtocol.self]
  let session = URLSession(configuration: configuration)

  await confirmation("Called network") { confirm in
    MockURLProtocol.startLoading = { request in
      let url = try #require(request.url)
      let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      let jsonString = "{\"update\":{\"id\":\"\", \"build_version\":\"\", \"build_number\":0,\"download_url\":\"\",\"app_name\":\"\",\"created_date\":\"\"}}"
      confirm()
      return (response, Data(jsonString.utf8))
    }
    
    await withCheckedContinuation { continuation in
      Updater(session: session).getUpdatesFromBackend(params: params) { result in
        switch result {
        case .success(let response):
          #expect(response.current == nil)
          #expect(response.update != nil)
          continuation.resume()
        case .failure(let error):
          #expect(Bool(false), "Should be a successful response but got \(error)")
        }
      }
    }
  }
}
