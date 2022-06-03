import Foundation

/// https://developers.themoviedb.org/3/movies/get-movie-details
struct MovieDetails: Codable {
    let runtime: Int?

    // Additional data fields, not included unless explicitly specified.
    let credits: Credits?
    let recommendations: Movies?
    let similar: Movies?
    let images: Images?
    let videos: Videos?
}
