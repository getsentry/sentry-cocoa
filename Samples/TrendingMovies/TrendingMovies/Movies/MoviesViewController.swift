import Kingfisher
import UIKit

class MoviesViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {
    typealias DataFetchingFunction = (TMDbClient, Int, @escaping (Swift.Result<Movies, Swift.Error>) -> Void) -> Void
    typealias SortFunction = (Movie, Movie) -> Bool

    var isInitialViewController: Bool = false
    var interactionName: String = "load-movies"
    var endedStartupTrace = false

    private let sortFunction: SortFunction?
    private let dataFetchingFunction: DataFetchingFunction
    private let enableStartupTimeLogging: Bool
    private let subtitleStyle: MovieCellConfigurator.SubtitleStyle
    private let client = TMDbClient(apiKey: TMDbCredentials.apiKey)
    private lazy var imageResolver = TMDbImageResolver(client: client)
    private lazy var genreResolver = TMDbGenreResolver(client: client)
    private lazy var cellConfigurator = MovieCellConfigurator(imageResolver: imageResolver, genreResolver: genreResolver, subtitleStyle: subtitleStyle)
    private var movies = [Movie]()

    private var pageNumber = 0
    private var totalPages = 0
    private var isLoadingNextPage = false

    private var previousCollectionViewWidth: CGFloat?
    private var cachedCellWidth: CGFloat?
    private var cellWidth: CGFloat {
        if let width = cachedCellWidth {
            return width
        } else {
            let calculatedWith = calculateCellWidth()
            cachedCellWidth = calculatedWith
            return calculatedWith
        }
    }

    private var scrollingSpan: Tracer.SpanHandle?

    init(subtitleStyle: MovieCellConfigurator.SubtitleStyle = .genre, enableStartupTimeLogging: Bool, sortFunction: SortFunction? = nil, dataFetchingFunction: @escaping DataFetchingFunction) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0.0
        layout.minimumLineSpacing = 15.0
        layout.sectionInset = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0)

        self.sortFunction = sortFunction
        self.dataFetchingFunction = dataFetchingFunction
        self.enableStartupTimeLogging = enableStartupTimeLogging
        self.subtitleStyle = subtitleStyle

        super.init(collectionViewLayout: layout)

        clearsSelectionOnViewWillAppear = true
        navigationItem.largeTitleDisplayMode = .always
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.backgroundColor = .white
        collectionView.prefetchDataSource = self
        collectionView.register(MovieCollectionViewCell.self, forCellWithReuseIdentifier: MovieCollectionViewCell.reuseIdentifier)
        collectionView.register(ActivityIndicatorSupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: ActivityIndicatorSupplementaryView.reuseIdentifier)

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = calculateEstimatedItemSize()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        invalidateCellWidthIfNecessary()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if totalPages == 0 {
            fetchInitialContent()
        }

        guard navigationController?.topViewController == self else {
            return
        }
        let navigationBar = navigationController?.navigationBar
        navigationBar?.setBackgroundImage(nil, for: .default)
        navigationBar?.shadowImage = nil
        navigationBar?.prefersLargeTitles = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Tracer.endTracing(interaction: interactionName)
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in _: UICollectionView) -> Int {
        1
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        movies.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MovieCollectionViewCell.reuseIdentifier, for: indexPath) as? MovieCollectionViewCell ?? MovieCollectionViewCell()
        configureCell(cell, indexPath: indexPath, collectionView: collectionView)
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionFooter:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ActivityIndicatorSupplementaryView.reuseIdentifier, for: indexPath) as? ActivityIndicatorSupplementaryView ?? ActivityIndicatorSupplementaryView(style: .gray)
            if shouldShowActivityIndicator {
                view.activityIndicatorView.startAnimating()
            }
            return view
        default:
            fatalError("Unexpected element kind \(kind)")
        }
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let movie = movies[indexPath.item]
        let detailViewController = MovieDetailViewController(
            movie: movie,
            client: client,
            imageResolver: imageResolver,
            genreResolver: genreResolver,
            errorHandler: { print($0) }
        )
        detailViewController.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailViewController, animated: true)
    }

    // MARK: UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, referenceSizeForFooterInSection _: Int) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: shouldShowActivityIndicator ? 30.0 : 0.0)
    }

    // MARK: UICollectionViewDataSourcePrefetching

    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let startPrefetch: (Swift.Result<URL?, Swift.Error>) -> Void = { result in
            switch result {
            case let .success(url):
                if let url = url {
                    ImagePrefetcher(urls: [url]).start()
                }
            case let .failure(error):
                print(error)
            }
        }
        for indexPath in indexPaths {
            let movie = movies[indexPath.item]
            imageResolver.getPosterImageURL(path: movie.posterPath, preferredWidth: Int(cellWidth), completion: startPrefetch)
            imageResolver.getBackdropImageURL(path: movie.backdropPath, preferredWidth: Int(UIScreen.main.bounds.width), completion: startPrefetch)
        }
    }

    // MARK: UIScrollViewDelegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollingSpan == nil {
            let efficiently = ProcessInfo.processInfo.arguments.contains("--io.sentry.sample.trending-movies.launch-arg.efficient-implementation")
            scrollingSpan = Tracer.startSpan(name: "movie-list-scroll-\(efficiently ? "efficiently" : "inefficiently")")
        }
        if scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height) <= 300.0 {
            fetchNextPage()
        }
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollingSpan?.end()
    }

    // MARK: Data

    private func fetchNextPage() {
        if isLoadingNextPage || (pageNumber > 0 && pageNumber >= totalPages) {
            return
        }
        isLoadingNextPage = true
        if !enableStartupTimeLogging || endedStartupTrace {
            Tracer.startTracing(interaction: interactionName)
        }
        dataFetchingFunction(client, pageNumber + 1) { result in
            Tracer.endTracing(interaction: self.interactionName)

            switch result {
            case let .success(response):
                let results = response.results.filter { !$0.adult }
                let insertionIndex = self.movies.count
                if let sortFunction = self.sortFunction {
                    self.movies.append(contentsOf: results.sorted(by: sortFunction))
                } else {
                    self.movies.append(contentsOf: results)
                }

                if insertionIndex == 0 {
                    self.collectionView.reloadData()
                } else {
                    let indexPaths = (insertionIndex ..< (insertionIndex + results.count)).map { IndexPath(item: $0, section: 0) }
                    self.collectionView.insertItems(at: indexPaths)
                }

                self.pageNumber += 1
                self.totalPages = response.totalPages
            case let .failure(error):
                print("[TrendingMovies] error fetching movies: \(error)")
            }
            self.isLoadingNextPage = false
        }
    }

    private func fetchInitialContent() {
        pageNumber = 0
        movies.removeAll()
        fetchNextPage()
    }

    // MARK: Layout

    private func calculateCellWidth() -> CGFloat {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            fatalError("Expected a UICollectionViewFlowLayout, got \(collectionView.collectionViewLayout) instead")
        }
        return floor((collectionView.bounds.size.width - layout.minimumInteritemSpacing - layout.sectionInset.left - layout.sectionInset.right) / 2.0)
    }

    private func invalidateCellWidthIfNecessary() {
        let collectionViewWidth = collectionView.bounds.size.width
        if previousCollectionViewWidth != collectionViewWidth {
            cachedCellWidth = nil
            previousCollectionViewWidth = collectionViewWidth
        }
    }

    private func calculateEstimatedItemSize() -> CGSize {
        let cell = MovieCollectionViewCell()
        let fittingSize = cell.systemLayoutSizeFitting(CGSize(width: cellWidth, height: UIView.layoutFittingCompressedSize.height))
        return CGSize(width: cellWidth, height: fittingSize.height)
    }

    private func configureCell(_ cell: MovieCollectionViewCell, indexPath: IndexPath, collectionView _: UICollectionView) {
        let movie = movies[indexPath.item]
        cellConfigurator.configureCell(cell, movie: movie, posterWidth: Int(cellWidth))
        cell.widthConstraint?.constant = cellWidth
        cell.widthConstraint?.isActive = true
        cell.isAccessibilityElement = true
        cell.accessibilityIdentifier = "movie \(indexPath.item)"
    }

    var shouldShowActivityIndicator: Bool {
        totalPages == 0 || pageNumber < totalPages
    }
}
