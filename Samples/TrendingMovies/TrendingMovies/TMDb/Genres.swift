import Foundation

/// A response to the /genre/movie/list or /genre/tv/list endpoints
struct Genres: Codable {
    let genres: [Genre]
}
