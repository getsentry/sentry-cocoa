import Kingfisher
import UIKit

class VideosViewController: MovieDetailSectionViewController<Video, VideoCollectionViewCell>, UICollectionViewDataSourcePrefetching {
    private let movie: Movie
    private let client: TMDbClient

    init(movie: Movie, client: TMDbClient, errorHandler: ErrorHandler?) {
        self.movie = movie
        self.client = client
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

    override func fetch(completion: @escaping (Swift.Result<[Video], Error>) -> Void) {
        let filter: ([Video]) -> [Video] = {
            $0.filter {
                $0.site.caseInsensitiveCompare("youtube") == .orderedSame
            }
        }
        if let videos = details?.videos?.results {
            completion(.success(filter(videos)))
        } else {
            let span = Tracer.startSpan(name: "load-movie-videos")
            span.annotate(key: "movie.title", value: String(movie.title))
            client.getMovieVideos(movie: movie) { result in
                span.end()
                completion(result.map { filter($0.results) })
            }
        }
    }

    override func configureCell(indexPath _: IndexPath, item: Video, cell: VideoCollectionViewCell) {
        cell.title = item.name

        // Trying fetching the maximum possible resolution first.
        cell.downloadTask = fetchThumbnailImage(video: item, type: .maximumResolution) { [weak cell] result in
            switch result {
            case let .success(image):
                cell?.thumbnailImage = image.image
            case let .failure(error):
                // If the response comes back with a 404 not found, switch to fetching
                // the medium quality thumbnail instead, which always exists.
                if case let .responseError(reason) = error,
                    case let .invalidHTTPStatusCode(response) = reason,
                    response.statusCode == 404 {
                    cell?.downloadTask = self.fetchThumbnailImage(video: item, type: .mediumQuality) { mediumResult in
                        switch mediumResult {
                        case let .success(image):
                            cell?.thumbnailImage = image.image
                        case let .failure(error):
                            self.errorHandler?(error)
                            cell?.thumbnailImage = nil
                        }
                    }
                } else {
                    self.errorHandler?(error)
                    cell?.thumbnailImage = nil
                }
            }
        }
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let url = YouTubeClient.getVideoURL(videoID: itemAtIndexPath(indexPath).key) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    // MARK: UICollectionViewDataSourcePrefetching

    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.map { itemAtIndexPath($0).key }
            .compactMap { YouTubeClient.getThumbnailURL(videoID: $0, type: .maximumResolution) }
        ImagePrefetcher(urls: urls).start()
    }

    // MARK: Private

    private func fetchThumbnailImage(video: Video, type: YouTubeClient.ThumbnailType, completion: ((Kingfisher.Result<Kingfisher.RetrieveImageResult, Kingfisher.KingfisherError>) -> Void)?) -> Kingfisher.DownloadTask? {
        if let url = YouTubeClient.getThumbnailURL(videoID: video.key, type: type) {
            return KingfisherManager.shared.retrieveImage(with: url, completionHandler: completion)
        }
        return nil
    }
}
