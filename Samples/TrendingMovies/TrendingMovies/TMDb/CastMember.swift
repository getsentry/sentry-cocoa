/// https://developers.themoviedb.org/3/movies/get-movie-credits
struct CastMember: Codable, Person {
    let character: String
    let id: Int
    let name: String
    let order: Int
    let profilePath: String?

    var role: String {
        character
    }
}
