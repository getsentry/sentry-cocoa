import Foundation
import SentryDistribution
import UIKit

enum UpdateUtil {
  @MainActor
  static func checkForUpdates() {
    let params = CheckForUpdateParams(accessToken: Constants.accessToken, organization: Constants.organization, project: Constants.project)
    Distribution.shared.checkForUpdate(params: params) { result in
      handleUpdateResult(result: result)
    }
  }
  
  @MainActor
  static func handleUpdateResult(result: Result<UpdateCheckResponse, Error>) {
    guard case let .success(releaseInfo) = result else {
      if case let .failure(error) = result {
        print("Error checking for update: \(error)")
      }
      return
    }
    
    guard let releaseInfo = releaseInfo.update else {
      print("Already up to date")
      return
    }
    
    UpdateUtil.installRelease(releaseInfo: releaseInfo)
  }
  
  @MainActor
  private static func installRelease(releaseInfo: ReleaseInfo) {
    guard let url = Distribution.shared.buildUrlForInstall(releaseInfo.downloadUrl) else {
      return
    }
    DispatchQueue.main.async {
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
  }
}
