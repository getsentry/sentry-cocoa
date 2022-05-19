/// https://developers.themoviedb.org/3/movies/get-movie-images
struct Images: Codable {
    let id: Int?
    let backdrops: [Image]
    let posters: [Image]
}
