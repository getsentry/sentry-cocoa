import Foundation
import Sentry
import SentrySampleShared
import SwiftUI

let key = "downloaded4"

@main
struct SwiftUIApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
  
  let downloaded: Bool

    init() {
        SentrySDKWrapper.shared.startSentry()
      self.downloaded = UserDefaults.standard.bool(forKey: key)
    }

    var body: some Scene {
        WindowGroup {
          VStack {
            Button("Start Background Download") {
                BgNet.shared.startDownload()
            }
            Text(downloaded ? "Downloaded" : "Not Downloaded")
            ContentView()
          }
        }
    }
}

class MyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {
  
  var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = MySceneDelegate.self
        }
        return configuration
    }

  func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

      // Register for push notifications
      let center = UNUserNotificationCenter.current()
      center.delegate = self
      center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
          print("Notification auth granted? \(granted), error=\(String(describing: error))")
      }

      application.registerForRemoteNotifications()

      // Log launch state so you can see if it's background
      print("didFinishLaunching state=\(application.applicationState.rawValue) options=\(String(describing: launchOptions))")

      return true
  }
  
  func application(_ application: UIApplication,
                   handleEventsForBackgroundURLSession identifier: String,
                   completionHandler: @escaping () -> Void) {
      print("handleEventsForBackgroundURLSession \(identifier)")
      backgroundCompletionHandler = completionHandler
  }
  
  // Called when a notification is delivered to a foreground app
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      print("Will present notification (foreground): \(notification.request.content.userInfo)")
      completionHandler([.banner, .sound])
  }

  // Called when user taps a notification
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
      print("Did receive notification response: \(response.notification.request.content.userInfo)")
      completionHandler()
  }
  
  @objc func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable : Any],
      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("Silent push received. App state=\(application.applicationState.rawValue) userInfo=\(userInfo)")
    completionHandler(.newData)
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
      UserDefaults.standard.set(true, forKey: key)
        print("[TEST] Download finished at \(location)")
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("urlSessionDidFinishEvents")
        DispatchQueue.main.async {
            (UIApplication.shared.delegate as? MyAppDelegate)?
                .backgroundCompletionHandler?()
          (UIApplication.shared.delegate as? MyAppDelegate)?
                .backgroundCompletionHandler = nil
        }
    }
}

class MySceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    var initializedSentry = false
    func sceneDidBecomeActive(_ scene: UIScene) {
        guard !initializedSentry else { return }
        guard UIApplication.shared.connectedScenes.first as? UIWindowScene != nil else {
            preconditionFailure("The test app should always have a UIWindowScene at this point")
        }

        SampleAppDebugMenu.shared.display()
        SentrySDK.feedback.showWidget()
        initializedSentry = true
    }
}
