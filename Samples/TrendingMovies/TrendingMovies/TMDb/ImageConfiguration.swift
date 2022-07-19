/// https://developers.themoviedb.org/3/configuration/get-api-configuration
struct ImageConfiguration: Codable {
    let secureBaseUrl: String
    let backdropSizes: [String]
    let posterSizes: [String]
    let profileSizes: [String]
}
