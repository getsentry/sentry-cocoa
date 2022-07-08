import Foundation

class TMDbGenreResolver {
    private let client: TMDbClient
    private var cachedGenres: Genres?

    init(client: TMDbClient) {
        self.client = client
    }

    /// Asynchronously retrieve the list of genre names for a list of genre IDs.
    ///
    /// - Parameters:
    ///   - ids: The genre IDs to get names for.
    ///   - completion: Closure called upon success or failure.
    func getGenres(ids: [Int], completion: @escaping (Result<[String], Swift.Error>) -> Void) {
        fetchGenres { result in
            switch result {
            case let .success(genres):
                completion(.success(ids.compactMap { id in genres.genres.first { $0.id == id }?.name }))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func fetchGenres(completion: @escaping (Result<Genres, Swift.Error>) -> Void) {
        if let cachedGenres = cachedGenres {
            completion(.success(cachedGenres))
        } else {
            client.getMovieGenres { result in
                switch result {
                case let .success(genres):
                    self.cachedGenres = genres
                case .failure:
                    break
                }
                completion(result)
            }
        }
    }
}
