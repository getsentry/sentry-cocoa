import Foundation
@testable import Sentry
import XCTest

final class URLSessionTaskHelperTests: XCTestCase {

    func testHTTPContentTypeInvalid() {
        let task = makeTask(
            headers: ["Content-Type": "image/jpeg"],
            body: "8J+YiQo="
        )

        let operationName = URLSessionTaskHelper.getGraphQLOperationName(from: task)

        XCTAssertNil(operationName)
    }

    func testHTTPBodyDataInvalid() {
        let task = makeTask(
            headers: ["Content-Type": "application/json"],
            body: "not json"
        )

        let operationName = URLSessionTaskHelper.getGraphQLOperationName(from: task)

        XCTAssertNil(operationName)
    }

    func testHTTPBodyDataMissing() {
        let task = makeTask(
            headers: ["Content-Type": "application/json"],
            body: nil
        )

        let operationName = URLSessionTaskHelper.getGraphQLOperationName(from: task)

        XCTAssertNil(operationName)
    }

    func testHTTPBodyDataValidGraphQL() {
        let task = makeTask(
            headers: ["Content-Type": "application/json"],
            body: """
                {
                    "operationName": "MyOperation",
                    "variables": {
                        "id": "1234"
                    },
                    "query": "query MyOperation($id: ID!) { node(id: $id) { id } }"
                }
            """
        )

        let operationName = URLSessionTaskHelper.getGraphQLOperationName(from: task)

        XCTAssertEqual(operationName, "MyOperation")
    }

}

private extension URLSessionTaskHelperTests {

    func makeTask(headers: [String: String], body: String?) -> URLSessionTask {
        var request = URLRequest(url: URL(string: "https://anything.com")!)
        request.httpBody = body?.data(using: .utf8)
        request.allHTTPHeaderFields = headers
        return URLSession(configuration: .ephemeral).dataTask(with: request)
    }

}
