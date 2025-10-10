import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A class for checking and installing app updates from Sentry's distribution service.
public final class Updater: Sendable {
  
  // MARK: - Public

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
  /// Updater.checkForUpdate(params: params) { result in
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
  public static func checkForUpdate(params: CheckForUpdateParams,
                                    completion: @escaping @Sendable (Result<UpdateCheckResponse, Swift.Error>) -> Void) {
    shared.getUpdatesFromBackend(params: params) { result in
      completion(result.mapError { $0 })
    }
  }

  #if canImport(UIKit)
  /// Install an update from the provided URL
  /// - Parameter url: The itms-services URL
  @MainActor public static func install(url: URL) {
    UIApplication.shared.open(url) { _ in
      // Post notification event before closing the app
      NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)

      // Close the app after a slight delay so it has time to execute code for the notification
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        // We need to exit since iOS doesn't start the install until the app exits
        exit(0)
      }
    }
  }
  #endif

  /// Obtain a URL to install an IPA
  /// - Parameter plistUrl: The URL to the plist containing the IPA information
  /// - Returns: a URL ready to install the IPA using itms-services
  public static func buildUrlForInstall(_ plistUrl: String) -> URL? {
    var components = URLComponents()
    components.scheme = "itms-services"
    components.queryItems = [
      URLQueryItem(name: "action", value: "download-manifest"),
      URLQueryItem(name: "url", value: plistUrl)
    ]
    return components.url
  }
  
  // MARK: - Internal
  init(session: URLSession = URLSession(configuration: URLSessionConfiguration.ephemeral)) {
    self.session = session
  }
  
  func getUpdatesFromBackend(
    params: CheckForUpdateParams,
    completion: @escaping @Sendable (Result<UpdateCheckResponse, Error>) -> Void) {
    guard var components = URLComponents(string: "https://\(params.hostname)/api/0/projects/\(params.organization)/\(params.project)/preprodartifacts/check-for-updates/") else {
      completion(.failure(.invalidUrl))
      return
    }
    guard let bundleId = params.appIdOverride ?? Bundle.main.bundleIdentifier else {
      completion(.failure(.noBundleId))
      return
    }
    
    components.queryItems = [
      URLQueryItem(name: "main_binary_identifier", value: params.binaryIdentifierOverride ?? uuid),
      URLQueryItem(name: "app_id", value: bundleId),
      URLQueryItem(name: "platform", value: "ios")
    ]
    if let shortVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
      components.queryItems?.append(URLQueryItem(name: "build_version", value: shortVersionString))
    }
    if let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
      components.queryItems?.append(URLQueryItem(name: "build_number", value: bundleVersion))
    }
    
    guard let url = components.url else {
      completion(.failure(.invalidUrl))
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(params.accessToken)", forHTTPHeaderField: "Authorization")

    session.perform(request, decode: UpdateCheckResponse.self) { result in
      completion(result)
    }
  }

  // MARK: - Private
  static let shared = Updater()
  private let session: URLSession
  private let uuid = BinaryParser.getMainBinaryUUID()
}
