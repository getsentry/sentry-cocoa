/// Protocol for a type that represents the profile of someone who received
/// attribution in the credits.
protocol Person {
    var id: Int { get }
    var name: String { get }
    var profilePath: String? { get }
    var role: String { get }
}
