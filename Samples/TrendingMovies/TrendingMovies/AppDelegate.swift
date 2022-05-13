import Kingfisher
import Sentry
import UIKit

class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if !result.isKind(of: UIButton.self) || result.isKind(of: UITextField.self) {
            return nil
        }
        return result
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var tracer: Tracer?

    // these are only used in benchmarking UI tests
    let benchmarkRetrieveValueButton = UIButton(type: .custom)
    let benchmarkValueTextField = UITextField(frame: .zero)
    let valueMarshalWindow = PassthroughWindow(frame: UIScreen.main.bounds)
    var startedBenchmark = false

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
            let views = [benchmarkValueTextField, benchmarkRetrieveValueButton]
            let stack = UIStackView(arrangedSubviews: views)
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .vertical
            vc.view.addSubview(stack)
            for view in views {
                view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    view.widthAnchor.constraint(equalToConstant: 100),
                    view.heightAnchor.constraint(equalToConstant: 50),
                ])
            }
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                stack.topAnchor.constraint(equalTo: vc.view.topAnchor)
            ])
            benchmarkValueTextField.accessibilityLabel = "io.sentry.accessibility-identifier.benchmarking-value-marshaling-text-field"
            benchmarkRetrieveValueButton.accessibilityLabel = "io.sentry.accessibility-identifier.benchmarking-value-marshaling-button"
            benchmarkRetrieveValueButton.addTarget(self, action: #selector(controlBenchmarks), for: .touchUpInside)
            benchmarkRetrieveValueButton.setTitle("Retrieve benchmark reading", for: .normal)
            valueMarshalWindow.rootViewController = vc
            valueMarshalWindow.windowLevel = .init(rawValue: window!.windowLevel.rawValue + 1.0) // ???: likely not needed
            valueMarshalWindow.isHidden = false
        }

        return true
    }

    @objc func controlBenchmarks() {
        if !startedBenchmark {
            startedBenchmark = true
            SentryBenchmarking.startBenchmarkProfile()
        } else {
            let value = SentryBenchmarking.retrieveBenchmarks()
            benchmarkValueTextField.text = String(value)
        }
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
