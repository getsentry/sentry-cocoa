import UIKit

class SimilarMoviesViewController: MovieDetailSectionViewController<Movie, MovieCollectionViewCell> {
    private let movie: Movie
    private let client: TMDbClient
    private let imageResolver: TMDbImageResolver
    private let genreResolver: TMDbGenreResolver
    private lazy var cellConfigurator = MovieCellConfigurator(imageResolver: imageResolver, genreResolver: genreResolver, subtitleStyle: .releaseYear)

    init(movie: Movie, client: TMDbClient, imageResolver: TMDbImageResolver, genreResolver: TMDbGenreResolver, errorHandler: ErrorHandler?) {
        self.movie = movie
        self.client = client
        self.imageResolver = imageResolver
        self.genreResolver = genreResolver

        super.init(errorHandler: errorHandler)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: MovieDetailSectionViewController

    override func fetch(completion: @escaping (Result<[Movie], Error>) -> Void) {
        if let movies = details?.similar?.results {
            completion(.success(movies))
        } else {
            let span = Tracer.startSpan(name: "load-similar-movies")
            span.annotate(key: "movie.title", value: movie.title)
            client.getSimilarMovies(movie: movie) { result in
                span.end()
                completion(result.map { $0.results })
            }
        }
    }

    override func configureCell(indexPath: IndexPath, item _: Movie, cell: MovieCollectionViewCell) {
        let movie = itemAtIndexPath(indexPath)
        cell.hideShadow = true
        cell.colors = colors
        cellConfigurator.configureCell(cell, movie: movie, posterWidth: Int(estimatedCellSize.width))
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let movie = itemAtIndexPath(indexPath)
        let detailViewController = MovieDetailViewController(movie: movie, client: client, imageResolver: imageResolver, genreResolver: genreResolver, errorHandler: errorHandler)
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}
