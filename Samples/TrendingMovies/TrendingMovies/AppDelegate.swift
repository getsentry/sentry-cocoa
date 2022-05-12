import Kingfisher
import Sentry
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var tracer: Tracer?

    // these are only used in benchmarking UI tests
    let benchmarkValueTextField = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    let valueMarshalWindow = UIWindow(frame: UIScreen.main.bounds)

    func application(_: UIApplication, willFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("[TrendingMovies] willFinishLaunchingWithOptions")
        Tracer.setUp(finishedLaunching: false)

        if ProcessInfo().arguments.contains("--io.sentry.ui-test.benchmarking") {
            let sharedCache = KingfisherManager.shared.cache
            sharedCache.clearMemoryCache()
            sharedCache.clearDiskCache()
            sharedCache.cleanExpiredDiskCache()
            URLCache.shared.removeAllCachedResponses()
        }

        return true
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("[TrendingMovies] didFinishLaunchingWithOptions")
        Tracer.setUp(finishedLaunching: true)
        
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.sessionTrackingIntervalMillis = 5_000
            // Sampling 100% - In Production you probably want to adjust this
            options.tracesSampleRate = 1.0
            options.enableFileIOTracking = true
            options.enableCoreDataTracking = true
            options.enableProfiling = true
            options.attachScreenshot = true
        }

        window = UIWindow(frame: UIScreen.main.bounds)
        let tabBarController = createTabBarController(items: [
            TabBarItemSpec(
                createViewController: createTrendingViewController,
                title: Titles.trending,
                icon: UIImage(named: "Trending")
            ),
            TabBarItemSpec(
                createViewController: createNowPlayingViewController,
                title: Titles.nowPlaying,
                icon: UIImage(named: "NowPlaying")
            ),
            TabBarItemSpec(
                createViewController: createUpcomingViewController,
                title: Titles.upcoming,
                icon: UIImage(named: "Upcoming")
            )
        ])
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        // TODO: show debug menu launcher?

        if ProcessInfo().arguments.contains("--io.sentry.ui-test.benchmarking") {
            let vc = UIViewController(nibName: nil, bundle: nil)
            vc.view.addSubview(benchmarkValueTextField)
            benchmarkValueTextField.accessibilityLabel = "io.sentry.accessibility-identifier.benchmarking-value-marshaling-text-field"
            valueMarshalWindow.rootViewController = vc
            valueMarshalWindow.windowLevel = .init(rawValue: window!.windowLevel.rawValue + 1.0)
            valueMarshalWindow.isHidden = false
        }

        return true
    }
}

private struct TabBarItemSpec {
    let createViewController: () -> UIViewController
    let title: String?
    let icon: UIImage?
}

private struct Titles {
    static let trending = NSLocalizedString("Trending", comment: "Title of the Trending view controller")
    static let nowPlaying = NSLocalizedString("Now Playing", comment: "Title of the Now Playing view controller")
    static let upcoming = NSLocalizedString("Upcoming", comment: "Title of the Upcoming view controller")
}

private func createTabBarController(items: [TabBarItemSpec]) -> UITabBarController {
    let tabBarController = UITabBarController(nibName: nil, bundle: nil)
    tabBarController.viewControllers = items.map {
        let viewController = $0.createViewController()
        viewController.title = $0.title
        viewController.tabBarItem.image = $0.icon
        return viewController
    }
    return tabBarController
}

private func createTrendingViewController() -> UIViewController {
    let viewController = MoviesViewController(subtitleStyle: .genre, enableStartupTimeLogging: true, sortFunction: { $1.popularity < $0.popularity }) {
        $0.getTrendingMovies(page: $1, window: .week, completion: $2)
    }
    viewController.title = Titles.trending
    viewController.isInitialViewController = true
    viewController.interactionName = "load-trending"
    return createNavigationController(rootViewController: viewController)
}

private func createNowPlayingViewController() -> UIViewController {
    let viewController = MoviesViewController(subtitleStyle: .genre, enableStartupTimeLogging: false, sortFunction: { $1.popularity < $0.popularity }) {
        $0.getNowPlaying(page: $1, completion: $2)
    }
    viewController.title = Titles.nowPlaying
    viewController.interactionName = "load-now-playing"
    return createNavigationController(rootViewController: viewController)
}

private func createUpcomingViewController() -> UIViewController {
    let viewController = MoviesViewController(subtitleStyle: .releaseDate, enableStartupTimeLogging: false, sortFunction: { $0.releaseDate < $1.releaseDate }) {
        $0.getUpcomingMovies(page: $1, completion: $2)
    }
    viewController.title = Titles.upcoming
    viewController.interactionName = "load-upcoming"
    return createNavigationController(rootViewController: viewController)
}

private func createNavigationController(rootViewController: UIViewController) -> UINavigationController {
    let navigationController = StatusBarForwardingNavigationController(rootViewController: rootViewController)
    navigationController.navigationBar.prefersLargeTitles = true
    return navigationController
}
