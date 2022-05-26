import Kingfisher
import TUSafariActivity
import UIKit

class MovieDetailViewController: UIViewController, UIScrollViewDelegate, MovieDetailViewDelegate {
    private struct Section {
        let title: String
        let viewController: MovieDetailSectionViewControllerProtocol
    }

    private let movie: Movie
    private let client: TMDbClient
    private let imageResolver: TMDbImageResolver
    private let genreResolver: TMDbGenreResolver
    private let errorHandler: ErrorHandler?

    private var detailView: MovieDetailView?
    private var barBackgroundView: MovieDetailBarBackgroundView?
    private var barBackgroundViewTopConstraint: NSLayoutConstraint?
    private var didActivateBarBackgroundViewHeightConstraint = false

    private var backdropImage: UIImage? {
        didSet { detailView?.backdropImage = backdropImage }
    }

    private var colors: ColorArt.Colors? {
        didSet { updateColors() }
    }

    private var genres: [String]? {
        didSet { detailView?.genres = genres }
    }

    private var details: MovieDetails? {
        didSet {
            detailView?.runtimeMinutes = details?.runtime
            addAllSections()
        }
    }

    private lazy var bgQueue = DispatchQueue(label: "io.sentry.movie-details.backdrop-fetches", qos: .default)

    private var sectionViewControllers = [MovieDetailSectionViewControllerProtocol]()
    private var hasAddedSections = false
    private var hasTriggeredInitialLoad = false
    private var hasFetchedBackdrop = false { didSet { endTraceIfNecessary() } }
    private var hasFetchedGenres = false { didSet { endTraceIfNecessary() } }
    private var hasFetchedMovieDetails = false { didSet { endTraceIfNecessary() } }
    private var hasFetchedSections = false { didSet { endTraceIfNecessary() } }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        (colors?.isDarkBackground ?? false) ? .lightContent : .default
    }

    init(movie: Movie,
         client: TMDbClient,
         imageResolver: TMDbImageResolver,
         genreResolver: TMDbGenreResolver,
         errorHandler: ErrorHandler?) {
        self.movie = movie
        self.client = client
        self.imageResolver = imageResolver
        self.genreResolver = genreResolver
        self.errorHandler = errorHandler

        super.init(nibName: nil, bundle: nil)

        navigationItem.title = movie.title
        navigationItem.titleView = UIView()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(showActivityViewController))
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let detailView = MovieDetailView()
        detailView.delegate = self
        detailView.detailViewDelegate = self

        let barBackgroundView = MovieDetailBarBackgroundView()
        barBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        detailView.addSubview(barBackgroundView)
        barBackgroundView.widthAnchor.constraint(equalTo: detailView.widthAnchor).isActive = true

        self.detailView = detailView
        self.barBackgroundView = barBackgroundView
        view = detailView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasTriggeredInitialLoad {
            Tracer.startTracing(interaction: "load-movie-details")
            fetchBackdrop()
            fetchGenres()
            fetchMovieDetails()
            hasTriggeredInitialLoad = true
        }
        guard navigationController?.topViewController == self else {
            return
        }
        let navigationBar = navigationController?.navigationBar
        navigationBar?.setBackgroundImage(UIImage(), for: .default)
        navigationBar?.shadowImage = UIImage()
        navigationBar?.prefersLargeTitles = false
        updateNavigationBarTintColor()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let detailView = detailView else {
            fatalError("Detail view was not loaded")
        }

        updateColors()

        detailView.backdropImage = backdropImage
        detailView.title = movie.title
        if movie.originalTitle != movie.title {
            detailView.originalTitle = movie.originalTitle
        }
        detailView.releaseDate = movie.releaseDate
        detailView.overview = movie.overview
        detailView.genres = genres
        detailView.runtimeMinutes = details?.runtime

        addAllSections()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !didActivateBarBackgroundViewHeightConstraint {
            // Need to wait until the view appears to be able to read an accurate value
            // for the navigation bar height.
            let navigationBarHeight = navigationController?.navigationBar.bounds.height ?? 0.0
            let barBackgroundHeight: CGFloat
            barBackgroundHeight = (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0.0) + navigationBarHeight
            barBackgroundView?.heightAnchor.constraint(equalToConstant: barBackgroundHeight).isActive = true
            didActivateBarBackgroundViewHeightConstraint = true
        }
    }

    // MARK: Sections

    private func addSections(_ sections: [Section]) {
        guard let detailView = detailView else {
            fatalError("addSections cannot be called before the view is loaded")
        }
        let initialCount = detailView.numberOfSections
        let newSectionCount = sections.count
        let loadedSectionCount = Atomic<Int>(0)
        for (index, spec) in sections.enumerated() {
            let viewController = spec.viewController
            viewController.details = details
            viewController.triggerFetch { state in
                switch state {
                case .hasContent:
                    self.addChildSectionViewController(viewController, title: spec.title, index: initialCount + index)
                case .empty, .failure:
                    break
                case .none, .triggered:
                    fatalError("The fetch completion handler should never be called with this state")
                }
                loadedSectionCount.mutate { $0 += 1 }
                if loadedSectionCount.value == newSectionCount {
                    self.hasFetchedSections = true
                }
            }
        }
    }

    private func addChildSectionViewController(_ viewController: MovieDetailSectionViewControllerProtocol, title: String, index: Int) {
        guard let detailView = detailView else {
            fatalError("addChildSectionViewController cannot be called before the view is loaded")
        }
        viewController.colors = colors
        addChild(viewController)
        viewController.view.heightAnchor.constraint(equalToConstant: viewController.estimatedCellSize.height).isActive = true
        let insertionIndex: Int
        if detailView.numberOfSections >= index {
            insertionIndex = index
        } else {
            insertionIndex = detailView.numberOfSections
        }
        detailView.insertSection(view: viewController.view, title: title, atIndex: insertionIndex)
        viewController.didMove(toParent: self)
        sectionViewControllers.append(viewController)
    }

    // MARK: UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let barBackgroundView = barBackgroundView else {
            fatalError("Expected barBackgroundView to be set")
        }
        let shouldHide = scrollView.contentOffset.y <= 20.0
        if barBackgroundView.isVisualEffectHidden != shouldHide {
            UIView.animate(withDuration: 0.15) {
                barBackgroundView.isVisualEffectHidden = shouldHide
            }
        }
    }

    // MARK: MovieDetailViewDelegate

    func movieDetailViewDidMoveToSuperview(movieDetailView: MovieDetailView) {
        barBackgroundViewTopConstraint?.isActive = false
        if let superview = movieDetailView.superview, let barBackgroundView = barBackgroundView {
            barBackgroundViewTopConstraint = barBackgroundView.topAnchor.constraint(equalTo: superview.topAnchor)
            barBackgroundViewTopConstraint?.isActive = true
        } else {
            barBackgroundViewTopConstraint = nil
        }
    }

    // MARK: Private

    private func fetchBackdrop() {
        /*
         * The following code sets up a nested span configuration. First
         * `fetch-backdrop` starts, then `retrieve-image-kingfisher`, which is
         * ended before `fetch-backdrop`.
         */
        let fetchBackdropSpan = Tracer.startSpan(name: "fetch-backdrop")
        imageResolver.getBackdropImageURL(path: movie.backdropPath ?? movie.posterPath, preferredWidth: Int(UIScreen.main.bounds.width)) { result in
            switch result {
            case let .success(url):
                if let url = url {
                    let kingfisherSpan = Tracer.startSpan(name: "retrieve-image-kingfisher")
                    KingfisherManager.shared.retrieveImage(with: url, options: [.callbackQueue(.dispatch(self.bgQueue))]) { imageResult in
                        switch imageResult {
                        case let .success(image):
                            let colors = getColors(image: image.image, errorHandler: self.errorHandler)

                            DispatchQueue.main.async {
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                self.backdropImage = image.image
                                self.colors = colors
                                CATransaction.commit()
                            }
                        case let .failure(error):
                            self.errorHandler?(error)
                        }
                        kingfisherSpan.end()
                    }
                }
            case let .failure(error):
                self.errorHandler?(error)
            }
            self.hasFetchedBackdrop = true
            fetchBackdropSpan.end()
        }
    }

    private func fetchGenres() {
        let span = Tracer.startSpan(name: "fetch-genre")
        genreResolver.getGenres(ids: movie.genreIds) { result in
            switch result {
            case let .success(genres):
                self.genres = genres
            case let .failure(error):
                self.errorHandler?(error)
            }
            self.hasFetchedGenres = true
            span.end()
        }
    }

    private func fetchMovieDetails() {
        let span = Tracer.startSpan(name: "fetch-movie-details")
        client.getMovieDetails(movie: movie, additionalData: [.credits, .videos, .similar]) { result in
            switch result {
            case let .success(details):
                self.details = details
            case let .failure(error):
                self.errorHandler?(error)
            }
            self.hasFetchedMovieDetails = true
            span.end()
        }
    }

    private func addAllSections() {
        if hasAddedSections || details == nil || !isViewLoaded {
            return
        }
        hasAddedSections = true
        addSections([
            Section(
                title: NSLocalizedString("Videos", comment: "Title for the Videos section"),
                viewController: VideosViewController(movie: movie, client: client, errorHandler: errorHandler)
            ),
            Section(
                title: NSLocalizedString("Cast", comment: "Title for the Cast section"),
                viewController: CreditsViewController(movie: movie, client: client, imageResolver: imageResolver, errorHandler: errorHandler)
            ),
            Section(
                title: NSLocalizedString("Similar Movies", comment: "Title for the Similar Movies section"),
                viewController: SimilarMoviesViewController(movie: movie, client: client, imageResolver: imageResolver, genreResolver: genreResolver, errorHandler: errorHandler)
            )
        ])
    }

    private func endTraceIfNecessary() {
        if hasFetchedGenres, hasFetchedBackdrop, hasFetchedMovieDetails, hasFetchedSections {
            Tracer.endTracing(interaction: "load-movie-details")
        }
    }

    @objc private func showActivityViewController() {
        if let url = TMDbClient.getMovieWebURL(movie: movie) {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [TUSafariActivity()])
            present(activityViewController, animated: true, completion: nil)
        }
    }

    private func updateColors() {
        detailView?.colors = colors
        barBackgroundView?.isDarkBackground = colors?.isDarkBackground ?? false
        updateNavigationBarTintColor()
        setNeedsStatusBarAppearanceUpdate()

        for viewController in sectionViewControllers {
            viewController.colors = colors
        }
    }

    private func updateNavigationBarTintColor() {
        navigationController?.navigationBar.tintColor = (colors?.isDarkBackground ?? false) ? .white : .black
    }
}

private func getColors(image: UIImage?, errorHandler: ErrorHandler?) -> ColorArt.Colors? {
    guard let image = image else {
        return nil
    }
    let width: CGFloat = 100.0
    let imageSize = image.size
    let height = ceil((imageSize.height / imageSize.width) * width)
    if let cgImage = image.cgImage {
        do {
            return try ColorArt.analyzeImage(cgImage, width: Int(width), height: Int(height), dominantEdge: .maxYEdge)
        } catch {
            errorHandler?(error)
        }
    }
    return nil
}
