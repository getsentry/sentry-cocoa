import Foundation

class TMDbImageResolver {
    private let client: TMDbClient
    private var cachedConfiguration: Configuration?

    init(client: TMDbClient) {
        self.client = client
    }

    /// Asynchronously retrieve the URL for a movie poster.
    ///
    /// - Parameters:
    ///   - path: The file path of the image.
    ///   - preferredWidth: The preferred width of the image. The size
    ///     of the image in the returned URL is not guaranteed to have
    ///     this width, it is a best effort.
    ///   - completion: Closure called upon success or failure.
    func getPosterImageURL(path: String?, preferredWidth: Int, completion: @escaping (Result<URL?, Swift.Error>) -> Void) {
        getURL(getSizes: { $0.posterSizes }, preferredWidth: preferredWidth, path: path, completion: completion)
    }

    /// Asynchronously retrieve the URL for a movie backdrop.
    ///
    /// - Parameters:
    ///   - path: The file path of the image.
    ///   - preferredWidth: The preferred width of the image. The size
    ///     of the image in the returned URL is not guaranteed to have
    ///     this width, it is a best effort.
    ///   - completion: Closure called upon success or failure.
    func getBackdropImageURL(path: String?, preferredWidth: Int, completion: @escaping (Result<URL?, Swift.Error>) -> Void) {
        getURL(getSizes: { $0.backdropSizes }, preferredWidth: preferredWidth, path: path, completion: completion)
    }

    /// Asynchronously retrieve the URL for a profile image.
    ///
    /// - Parameters:
    ///   - path: The file path of the image.
    ///   - preferredWidth: The preferred width of the image. The size
    ///     of the image in the returned URL is not guaranteed to have
    ///     this width, it is a best effort.
    ///   - completion: Closure called upon success or failure.
    func getProfileImageURL(path: String?, preferredWidth: Int, completion: @escaping (Result<URL?, Swift.Error>) -> Void) {
        getURL(getSizes: { $0.profileSizes }, preferredWidth: preferredWidth, path: path, completion: completion)
    }

    private func getURL(getSizes: @escaping (ImageConfiguration) -> [String], preferredWidth: Int, path: String?, completion: @escaping (Result<URL?, Swift.Error>) -> Void) {
        guard let path = path else {
            completion(.success(nil))
            return
        }
        fetchConfiguration { result in
            switch result {
            case let .success(configuration):
                if let preferredSize = getPreferredSize(sizes: getSizes(configuration.images), preferredWidth: preferredWidth) {
                    let urlString = configuration.images.secureBaseUrl + preferredSize + path
                    completion(.success(URL(string: urlString)))
                } else {
                    completion(.success(nil))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func fetchConfiguration(completion: @escaping (Result<Configuration, Swift.Error>) -> Void) {
        if let cachedConfiguration = cachedConfiguration {
            completion(.success(cachedConfiguration))
        } else {
            client.getConfiguration { result in
                switch result {
                case let .success(configuration):
                    self.cachedConfiguration = configuration
                case .failure:
                    break
                }
                completion(result)
            }
        }
    }
}

private func supportedWidths(sizes: [String]) -> [Int] {
    return sizes.compactMap { size in
        if let range = size.range(of: "w"), let width = Int(size[range.upperBound...]) {
            return width
        } else {
            return nil
        }
    }.sorted()
}

private func getPreferredSize(sizes: [String], preferredWidth: Int) -> String? {
    if sizes.isEmpty {
        return nil
    }
    let widths = supportedWidths(sizes: sizes)
    for width in widths {
        if width >= preferredWidth {
            return "w\(width)"
        }
    }
    return sizes.last
}
