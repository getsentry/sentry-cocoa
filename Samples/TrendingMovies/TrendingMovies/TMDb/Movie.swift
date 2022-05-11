import Foundation

/// https://developers.themoviedb.org/3/movies/get-now-playing
struct Movie: Codable {
    let posterPath: String?
    let adult: Bool
    let overview: String
    let releaseDate: Date
    let genreIds: [Int]
    let id: Int
    let originalTitle: String
    let title: String
    let backdropPath: String?
    let popularity: Double
}
