import Foundation

// swiftlint:disable type_body_length

class TMDbClient: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    enum TMDbClientError: Swift.Error {
        case URLConstructionFailed
        case unknown
    }

    enum AdditionalData: String {
        case credits
        case recommendations
        case similar
        case images
        case videos
    }

    enum TimeWindow: String {
        case day
        case week
    }

    // swiftlint:disable force_unwrapping
    private static let baseURL = URL(string: "https://api.themoviedb.org/3")!
    // swiftlint:enable force_unwrapping

    private let apiKey: String

    struct Request {
        struct Closure {
            var configurationCompletion: ((Result<Configuration, Swift.Error>) -> Void)?
            var genreCompletion: ((Result<Genres, Swift.Error>) -> Void)?
            var nowPlayingCompletion: ((Result<Movies, Swift.Error>) -> Void)?
            var recommendationsCompletion: ((Result<Movies, Swift.Error>) -> Void)?
            var similarCompletion: ((Result<Movies, Swift.Error>) -> Void)?
            var upcomingCompletion: ((Result<Movies, Swift.Error>) -> Void)?
            var trendingCompletion: ((Result<Movies, Swift.Error>) -> Void)?
            var detailsCompletion: ((Result<MovieDetails, Swift.Error>) -> Void)?
            var creditsCompletion: ((Result<Credits, Swift.Error>) -> Void)?
            var videosCompletion: ((Result<Videos, Swift.Error>) -> Void)?
            var imagesCompletion: ((Result<Images, Swift.Error>) -> Void)?
            var personDetailsCompletion: ((Result<PersonDetails, Swift.Error>) -> Void)?
        }

        var closure: Closure?
        var data: Data?
    }

    private var requests = [URLSessionTask: Request]()

    private lazy var session: URLSession = {
        return URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }()

    /// Constructs a new `TMDbClient`
    ///
    /// - Parameter apiKey: The v3 API key to use for all requests.
    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Requests the API configuration information, including supported image
    /// sizes and the base URLs to get images from.
    ///
    /// - Parameter completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getConfiguration(completion: @escaping (Result<Configuration, Swift.Error>) -> Void) -> URLSessionTask? {
        guard let url = getRequestURL(path: "/configuration", description: "Get Configuration", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.configurationCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Requests a list of the available movie genres.
    ///
    /// - Parameters:
    ///   - locale: The locale used to translate the fields, if possible.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getMovieGenres(locale: Locale = .current, completion: @escaping (Result<Genres, Swift.Error>) -> Void) -> URLSessionTask? {
        var queryItems = [URLQueryItem]()
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        guard let url = getRequestURL(path: "/genre/movie/list", description: "Get Movie Genres", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.genreCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Requests a list of movies that are currently playing in theaters.
    ///
    /// - Parameters:
    ///   - page: The page index to fetch (from 1 to 1000, inclusive).
    ///   - locale: The locale to filter results down to.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getNowPlaying(page: Int = 1, locale: Locale = .current, completion: @escaping (Result<Movies, Swift.Error>) -> Void) -> URLSessionTask? {
        precondition(page >= 1 && page <= 1_000)
        var queryItems = [URLQueryItem(name: "page", value: String(page))]
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        if let region = getRegionQueryItem(locale: locale) {
            queryItems.append(region)
        }
        guard let url = getRequestURL(path: "/movie/now_playing", description: "Get Now Playing", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.nowPlayingCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Requests a list of recommended movies for a movie.
    ///
    /// - Parameters:
    ///   - movie: The movie to request recommendations for.
    ///   - page: The page index to fetch (from 1 to 1000, inclusive).
    ///   - locale: The locale to use to translate fields.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getMovieRecommendations(movie: Movie, page: Int = 1, locale: Locale = .current, completion: @escaping (Result<Movies, Swift.Error>) -> Void) -> URLSessionTask? {
        precondition(page >= 1 && page <= 1_000)
        var queryItems = [URLQueryItem(name: "page", value: String(page))]
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        guard let url = getRequestURL(path: "/movie/\(movie.id)/recommendations", description: "Get Movie Recommendations", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.recommendationsCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Requests a list of movies that are similar to another movie.
    ///
    /// - Parameters:
    ///   - movie: The movie to request similar movies for.
    ///   - page: The page index to fetch (from 1 to 1000, inclusive).
    ///   - locale: The locale to use to translate fields.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getSimilarMovies(movie: Movie, page: Int = 1, locale: Locale = .current, completion: @escaping (Result<Movies, Swift.Error>) -> Void) -> URLSessionTask? {
        precondition(page >= 1 && page <= 1_000)
        var queryItems = [URLQueryItem(name: "page", value: String(page))]
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        guard let url = getRequestURL(path: "/movie/\(movie.id)/similar", description: "Get Similar Movies", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.similarCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Requests a list of movies that are upcoming in theaters.
    ///
    /// - Parameters:
    ///   - page: The page index to fetch (from 1 to 1000, inclusive).
    ///   - locale: The locale to filter results down to.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getUpcomingMovies(page: Int = 1, locale: Locale = .current, completion: @escaping (Result<Movies, Swift.Error>) -> Void) -> URLSessionTask? {
        precondition(page >= 1 && page <= 1_000)
        var queryItems = [URLQueryItem(name: "page", value: String(page))]
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        if let region = getRegionQueryItem(locale: locale) {
            queryItems.append(region)
        }
        guard let url = getRequestURL(path: "/movie/upcoming", description: "Get Upcoming Movies", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.upcomingCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Requests a list of movies that are trending.
    ///
    /// - Parameters:
    ///   - page: The page index to fetch (from 1 to 1000, inclusive).
    ///   - window: The window (day/week) in which to get trending movies.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getTrendingMovies(page: Int = 1, window: TimeWindow, completion: @escaping (Result<Movies, Swift.Error>) -> Void) -> URLSessionTask? {
        precondition(page >= 1 && page <= 1_000)
        let queryItems = [URLQueryItem(name: "page", value: String(page))]
        guard let url = getRequestURL(path: "/trending/movie/\(window.rawValue)", description: "Get Trending Movies", queryItems: queryItems) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.trendingCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Request detailed information for a movie.
    ///
    /// - Parameters:
    ///   - movie: The movie to request detailed information for.
    ///   - locale: The locale used to translate the fields, if possible.
    ///   - additionalData: Additional data to include in the response.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getMovieDetails(movie: Movie, locale: Locale = .current, additionalData: [AdditionalData]? = nil, completion: @escaping (Result<MovieDetails, Swift.Error>) -> Void) -> URLSessionTask? {
        var queryItems = [URLQueryItem]()
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        if let additionalData = additionalData, !additionalData.isEmpty {
            let joined = additionalData.map { $0.rawValue }.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "append_to_response", value: joined))
        }
        guard let url = getRequestURL(path: "/movie/\(movie.id)", description: "Get Movie Details", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.detailsCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Request a list of cast and crew members associated with the movie.
    ///
    /// - Parameters:
    ///   - movie: The movie to get credits for.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getMovieCredits(movie: Movie, completion: @escaping (Result<Credits, Swift.Error>) -> Void) -> URLSessionTask? {
        guard let url = getRequestURL(path: "/movie/\(movie.id)/credits", description: "Get Movie Credits", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.creditsCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Request a list of videos associated with the movie.
    ///
    /// - Parameters:
    ///   - movie: The movie to get videos for.
    ///   - locale: The locale used to translate the fields, if possible.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getMovieVideos(movie: Movie, locale: Locale = .current, completion: @escaping (Result<Videos, Swift.Error>) -> Void) -> URLSessionTask? {
        var queryItems = [URLQueryItem]()
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        guard let url = getRequestURL(path: "/movie/\(movie.id)/videos", description: "Get Movie Videos", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.videosCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Request images associated with a movie.
    ///
    /// - Parameters:
    ///   - movie: The movie to get images for.
    ///   - locale: The locale to filter images by.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getMovieImages(movie: Movie, locale: Locale = .current, completion: @escaping (Result<Images, Swift.Error>) -> Void) -> URLSessionTask? {
        var queryItems = [URLQueryItem(name: "include_image_language", value: "en,null")]
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        guard let url = getRequestURL(path: "/movie/\(movie.id)/images", description: "Get Movie Images", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.imagesCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Requests detailed information for a person.
    ///
    /// - Parameters:
    ///   - person: The person to get detailed information for.
    ///   - locale: The locale used to translate the fields, if possible.
    ///   - completion: Closure to be called when the request succeeds or fails.
    /// - Returns: A task that can be used to cancel the request.
    @discardableResult
    func getPersonDetails(person: Person, locale: Locale = .current, completion: @escaping (Result<PersonDetails, Swift.Error>) -> Void) -> URLSessionTask? {
        var queryItems = [URLQueryItem]()
        if let language = getLanguageQueryItem(locale: locale) {
            queryItems.append(language)
        }
        guard let url = getRequestURL(path: "/person/\(person.id)", description: "Get Person Details", queryItems: nil) else {
            completion(.failure(TMDbClientError.URLConstructionFailed))
            return nil
        }

        let task: URLSessionDataTask
        if ProcessInfo.processInfo.arguments.contains("io.sentry.launch-argument.delegate-based-session-tasks") {
            task = session.dataTask(with: url)
            var request = Request()
            request.closure = Request.Closure()
            request.closure?.personDetailsCompletion = completion
            requests[task] = request
        } else {
            task = session.dataTask(with: url) { data, response, error in
                self.handleRequestCompletion(data: data, response: response, error: error, completion: completion)
            }
        }
        task.taskDescription = description
        task.resume()

        return task
    }

    /// Constructs a URL for a GET request to the TMDb API.
    /// - Parameters:
    ///   - path: The path to request (e.g. /movies/now_playing).
    ///   - description: A human readable description of the request.
    ///   - queryItems: Query parameters to pass in the URL.
    /// - Returns: A URL suitable for the necessary GET request, or `nil` if it couldn't be constructed.
    private func getRequestURL(path: String, description _: String, queryItems: [URLQueryItem]?) -> URL? {
        guard var components = URLComponents(url: TMDbClient.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = components.path.appending(path)
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)] + (queryItems ?? [])

        guard let url = components.url else {
            return nil
        }

        return url
    }

    /// Returns the TMDb web URL for the specified movie.
    ///
    /// - Parameter movie: The movie to get a URL for.
    /// - Returns: The URL to the movie on TMDb.
    static func getMovieWebURL(movie: Movie) -> URL? {
        URL(string: "https://www.themoviedb.org/movie/" + String(movie.id))
    }

    /// Returns the TMDb web URL for the specified person.
    ///
    /// - Parameter movie: The person to get a URL for.
    /// - Returns: The URL to the person on TMDb.
    static func getPersonURL(person: Person) -> URL? {
        URL(string: "https://www.themoviedb.org/person/" + String(person.id))
    }

    func handleRequestCompletion<Response: Decodable>(data: Data?, response: URLResponse?, error: Swift.Error?, completion: @escaping (Result<Response, Swift.Error>) -> Void) {
        if let data = data, let response = response as? HTTPURLResponse, response.statusCode >= 200, response.statusCode < 300 {
            completion(Result {
                try self.decoder.decode(Response.self, from: data)
            })
        } else if let error = error {
            completion(.failure(error))
        } else {
            completion(.failure(TMDbClientError.unknown))
        }
    }

    // MARK: NSURLSessionDataDelegate

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        requests[dataTask]?.data = data
    }

    // MARK: NSURLSessionTaskDelegate

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = requests[task] else { return }

        if let completion = request.closure?.configurationCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.genreCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.nowPlayingCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.recommendationsCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.similarCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.upcomingCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.trendingCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.detailsCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.creditsCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.videosCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.imagesCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        } else if let completion = request.closure?.personDetailsCompletion {
            handleRequestCompletion(data: request.data, response: task.response, error: error, completion: completion)
        }

        requests[task] = nil
    }
}

private func getLanguageQueryItem(locale: Locale) -> URLQueryItem? {
    if let languageCode = locale.languageCode {
        return URLQueryItem(name: "language", value: languageCode)
    }
    return nil
}

private func getRegionQueryItem(locale: Locale) -> URLQueryItem? {
    if let regionCode = locale.regionCode {
        return URLQueryItem(name: "region", value: regionCode)
    }
    return nil
}

// swiftlint:enable type_body_length
