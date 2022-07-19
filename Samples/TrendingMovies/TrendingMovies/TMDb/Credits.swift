/// https://developers.themoviedb.org/3/movies/get-movie-credits
struct Credits: Codable {
    let cast: [CastMember]
    let crew: [CrewMember]
}
