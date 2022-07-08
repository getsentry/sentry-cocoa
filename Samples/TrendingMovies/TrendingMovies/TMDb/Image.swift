/// https://developers.themoviedb.org/3/movies/get-movie-images
struct Image: Codable {
    let aspectRatio: Double
    let filePath: String
    let height: Int
    let width: Int
    let iso6391: String?
}
