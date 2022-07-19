import Kingfisher
import Sentry
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var tracer: Tracer?

    func application(_: UIApplication, willFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("[TrendingMovies] willFinishLaunchingWithOptions")
        Tracer.setUp(finishedLaunching: false)

        func clearCaches() {
            let sharedCache = KingfisherManager.shared.cache
            sharedCache.clearMemoryCache()
            sharedCache.clearDiskCache()
            sharedCache.cleanExpiredDiskCache()
            URLCache.shared.removeAllCachedResponses()
        }

        if ProcessInfo().arguments.contains("--clear") {
            clearCaches()
        }

        return true
    }

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("[TrendingMovies] didFinishLaunchingWithOptions")
        Tracer.setUp(finishedLaunching: true)

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
