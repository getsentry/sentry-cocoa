import Foundation
import SentryDistribution
import UIKit

enum UpdateUtil {
  @MainActor
  static func checkForUpdates() {
    let params = CheckForUpdateParams(accessToken: Constants.accessToken, organization: Constants.organization, project: Constants.project)
    Updater.checkForUpdate(params: params) { result in
      handleUpdateResult(result: result)
    }
  }
  
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

  private static func installRelease(releaseInfo: ReleaseInfo) {
    guard let url = Updater.buildUrlForInstall(releaseInfo.downloadUrl) else {
      return
    }
    DispatchQueue.main.async {
      Updater.install(url: url)
    }
  }
}
