/// A struct to represent uncovered test cases that are not implemented.
public struct MissingTestCase {
    /// The title of the uncovered test case.
    public let title: String
    /// A specification of the uncovered test case written in Gherkin syntax https://cucumber.io/docs/gherkin/reference/.
    public let description: String
    /// A link to the deleted test case, if applicable.
    public let deletedTestCaseLink: String?

    /// Initializes a new MissingTestCase.
    /// - Parameters:
    ///   - title: The title of the uncovered test case.
    ///   - description: A specification of the uncovered test case written in Gherkin syntax.
    ///   - deletedTestCaseLink: A link to the deleted test case, if applicable.
    public init(title: String, description: String, deletedTestCaseLink: String? = nil) {
        self.title = title
        self.description = description
        self.deletedTestCaseLink = deletedTestCaseLink
    }
}
