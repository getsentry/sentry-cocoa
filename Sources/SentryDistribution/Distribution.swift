import Foundation
import UIKit

@MainActor
public final class Distribution {
  // MARK: - Public
  public static let shared = Distribution()

  /// Checks if there is an update available for the app, based on the provided `params`.
  ///
  ///
  /// - Parameters:
  ///   - params: A `CheckForUpdateParams` object.
  ///   - completion: A closure that is called with the result of the update check.
  ///
  /// - Example:
  /// ```
  /// let params = CheckForUpdateParams(accessToken: "your_access_token")
  /// checkForUpdate(params: params) { result in
  ///     switch result {
  ///     case .success(let releaseInfo):
  ///       if let releaseInfo = releaseInfo.update {
  ///         print("Update found: \(releaseInfo)")
  ///       } else {
  ///         print("Already up to date")
  ///       }
  ///     case .failure(let error):
  ///         print("Error checking for update: \(error)")
  ///     }
  /// }
  /// ```
  public func checkForUpdate(params: CheckForUpdateParams,
                             completion: @escaping (@MainActor (Result<UpdateCheckResponse, Error>) -> Void)) {
    getUpdatesFromBackend(params: params, completion: completion)
  }

  /// Obtain a URL to install an IPA
  /// - Parameter plistUrl: The URL to the plist containing the IPA information
  /// - Returns: a URL ready to install the IPA using Itunes Services
  public func buildUrlForInstall(_ plistUrl: String) -> URL? {
    guard var components = URLComponents(string: "itms-services://") else {
      return nil
    }
    components.queryItems = [
      URLQueryItem(name: "action", value: "download-manifest"),
      URLQueryItem(name: "url", value: plistUrl)
    ]
    return components.url
  }

  // MARK: - Private
  private lazy var session = URLSession(configuration: URLSessionConfiguration.ephemeral)
  private lazy var uuid = BinaryParser.getMainBinaryUUID()
  
  private func getUpdatesFromBackend(params: CheckForUpdateParams,
                                     completion: @escaping (@MainActor (Result<UpdateCheckResponse, Error>) -> Void)) {
    guard var components = URLComponents(string: "http://\(params.hostname)/api/0/projects/\(params.organization)/\(params.project)/preprodartifacts/check-for-updates/") else {
      fatalError("Invalid URL")
    }
    
    components.queryItems = [
      URLQueryItem(name: "main_binary_identifier", value: params.binaryIdentifierOverride ?? uuid),
      URLQueryItem(name: "app_id", value: params.appIdOverride ?? Bundle.main.bundleIdentifier),
      URLQueryItem(name: "platform", value: "ios"),
      URLQueryItem(name: "version", value: "1.0")
    ]
    
    guard let url = components.url else {
      fatalError("Invalid URL")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(params.accessToken)", forHTTPHeaderField: "Authorization")
    
    session.checkForUpdate(request) { result in
      completion(result)
    }
  }
}
