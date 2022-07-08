import Foundation

/// https://developers.themoviedb.org/3/genres/get-movie-list
struct Genre: Codable {
    let id: Int
    let name: String
}
