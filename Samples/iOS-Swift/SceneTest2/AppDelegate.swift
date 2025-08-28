//
//  AppDelegate.swift
//  SceneTest2
//
//  Created by Noah Martin on 8/27/25.
//

import UIKit
import SentrySampleShared

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  var backgroundCompletionHandler: (() -> Void)?


  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    SentrySDKWrapper.shared.startSentry()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      BgNet.shared.startDownload()
    }
    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }


}

final class BgNet {
    static let shared = BgNet()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.example.bg.repro")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        session = URLSession(configuration: config, delegate: Delegate.shared, delegateQueue: nil)
    }

    func startDownload() {
        // Use any HTTP(S) file that’s ~10–50 MB so you have time to kill the app
        let url = URL(string: "https://download.thinkbroadband.com/20MB.zip")!
        let task = session.downloadTask(with: url)
        task.resume()
        print("[TEST] Started background download \(task.taskIdentifier)")
    }
}

final class Delegate: NSObject, URLSessionDownloadDelegate {
    static let shared = Delegate()

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        print("[TEST] Download finished at \(location)")
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("urlSessionDidFinishEvents")
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as? AppDelegate)?
                .backgroundCompletionHandler?()
          (UIApplication.shared.delegate as? AppDelegate)?
                .backgroundCompletionHandler = nil
        }
    }
}

