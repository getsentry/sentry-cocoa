/// https://developers.themoviedb.org/3/movies/get-movie-credits
struct CrewMember: Codable, Person {
    let id: Int
    let job: String
    let name: String
    let profilePath: String?

    var role: String {
        job
    }
}
