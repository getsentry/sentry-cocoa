import Kingfisher
import UIKit

class CreditsViewController: MovieDetailSectionViewController<Person, CreditCollectionViewCell>, UICollectionViewDataSourcePrefetching {
    private let movie: Movie
    private let client: TMDbClient
    private let imageResolver: TMDbImageResolver

    init(movie: Movie, client: TMDbClient, imageResolver: TMDbImageResolver, errorHandler: ErrorHandler?) {
        self.movie = movie
        self.client = client
        self.imageResolver = imageResolver
        super.init(errorHandler: errorHandler)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.prefetchDataSource = self
    }

    // MARK: MovieDetailSectionViewController

    override func fetch(completion: @escaping (Swift.Result<[Person], Swift.Error>) -> Void) {
        let sort: (Credits) -> [Person] = {
            $0.cast.sorted { $0.order < $1.order }
        }
        if let credits = details?.credits {
            completion(.success(sort(credits)))
        } else {
            let span = Tracer.startSpan(name: "load-movie-credits")
            span.annotate(key: "movie.title", value: movie.title)
            client.getMovieCredits(movie: movie) { result in
                span.end()
                completion(result.map { sort($0) })
            }
        }
    }

    override func configureCell(indexPath: IndexPath, item _: Person, cell: CreditCollectionViewCell) {
        let profile = itemAtIndexPath(indexPath)
        cell.colors = colors
        cell.name = profile.name
        cell.role = profile.role

        getProfileImageURL(profile: profile) { urlResult in
            switch urlResult {
            case let .success(url):
                if let url = url {
                    cell.downloadTask = KingfisherManager.shared.retrieveImage(with: url) { imageResult in
                        switch imageResult {
                        case let .success(image):
                            cell.profileImage = image.image
                        case let .failure(error):
                            self.errorHandler?(error)
                        }
                    }
                }
            case let .failure(error):
                self.errorHandler?(error)
            }
        }
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let url = TMDbClient.getPersonURL(person: itemAtIndexPath(indexPath)) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    // MARK: UICollectionViewDataSourcePrefetching

    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            getProfileImageURL(profile: itemAtIndexPath(indexPath)) { result in
                switch result {
                case let .success(url):
                    if let url = url {
                        ImagePrefetcher(urls: [url]).start()
                    }
                case let .failure(error):
                    self.errorHandler?(error)
                }
            }
        }
    }

    // MARK: Private

    func getProfileImageURL(profile: Person, completion: @escaping (Swift.Result<URL?, Swift.Error>) -> Void) {
        imageResolver.getProfileImageURL(path: profile.profilePath, preferredWidth: Int(CreditCollectionViewCell.profileImageSize), completion: completion)
    }
}
