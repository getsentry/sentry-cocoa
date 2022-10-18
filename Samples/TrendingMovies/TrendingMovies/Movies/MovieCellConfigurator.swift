import Kingfisher
import UIKit

class MovieCellConfigurator {
    enum SubtitleStyle {
        case genre
        case releaseDate
        case releaseYear
    }

    private let imageResolver: TMDbImageResolver
    private let genreResolver: TMDbGenreResolver
    private let subtitleStyle: SubtitleStyle

    private lazy var releaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private lazy var releaseYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    init(imageResolver: TMDbImageResolver, genreResolver: TMDbGenreResolver, subtitleStyle: SubtitleStyle) {
        self.imageResolver = imageResolver
        self.genreResolver = genreResolver
        self.subtitleStyle = subtitleStyle
    }

    func configureCell(_ cell: MovieCollectionViewCell, movie: Movie, posterWidth: Int) {
        print("[TrendingMovies] configuring cell for movie: \(movie.id) (\(movie.title))")
        cell.titleLabel.text = movie.title

        Tracer.startTracing(interaction: "poster-retrieval")
        imageResolver.getPosterImageURL(path: movie.posterPath, preferredWidth: posterWidth) { result in
            Tracer.endTracing(interaction: "poster-retrieval")
            switch result {
            case let .success(url):
                if let url = url {
                    print("[TrendingMovies] got poster image URL for movie: \(movie.id) (\(movie.title)): \(url)")
                    if ProcessInfo.processInfo.arguments.contains("--io.sentry.sample.trending-movies.launch-arg.efficient-implementation") {
                        cell.downloadTask = KingfisherManager.shared.retrieveImage(with: url) { [weak cell] imageResult in
                            switch imageResult {
                            case let .success(image):
                                print("[TrendingMovies] set poster image for movie: \(movie.id) (\(movie.title))")
                                cell?.posterImage = image.image
                            case let .failure(error):
                                print(error)
                                cell?.posterImage = nil
                            }
                        }
                    } else {
                        cell.uncachedDownloadTask = cell.uncachedURLSession.downloadTask(with: URLRequest(url: url), completionHandler: { [weak cell] downloadedURL, _, error in
                            if error != nil || downloadedURL == nil {
                                cell?.posterImage = nil
                                return
                            }

                            guard let downloadedURLString = downloadedURL?.relativePath else {
                                cell?.posterImage = nil
                                return
                            }

                            DispatchQueue.main.async {
                                cell?.posterImage = UIImage(contentsOfFile: downloadedURLString)
                            }
                        })
                        cell.uncachedDownloadTask?.resume()
                    }
                } else {
                    cell.posterImage = nil
                }
            case let .failure(error):
                print(error)
                cell.posterImage = nil
            }
        }

        switch subtitleStyle {
        case .genre:
            genreResolver.getGenres(ids: movie.genreIds) { result in
                switch result {
                case let .success(genres):
                    cell.subtitleLabel.text = genres.prefix(2).joined(separator: ", ")
                case let .failure(error):
                    print(error)
                }
            }
        case .releaseDate:
            cell.subtitleLabel.text = releaseDateFormatter.string(from: movie.releaseDate)
        case .releaseYear:
            cell.subtitleLabel.text = releaseYearFormatter.string(from: movie.releaseDate)
        }
    }
}
