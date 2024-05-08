import Foundation
import Nimble
@testable import Sentry
import XCTest

final class URLSessionTaskTests: XCTestCase {

    func testHTTPContentTypeInvalid() {
        let task = makeTask(
            headers: ["Content-Type": "image/jpeg"],
            body: "8J+YiQo="
        )

        let operationName = task.getGraphQLOperationName()
        
        expect(operationName) == nil
    }

    func testHTTPBodyDataInvalid() {
        let task = makeTask(
            headers: ["Content-Type": "application/json"],
            body: "not json"
        )

        let operationName = task.getGraphQLOperationName()

        expect(operationName) == nil
    }

    func testHTTPBodyDataMissing() {
        let task = makeTask(
            headers: ["Content-Type": "application/json"],
            body: nil
        )

        let operationName = task.getGraphQLOperationName()

        expect(operationName) == nil
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

        let operationName = task.getGraphQLOperationName()

        expect(operationName) == "MyOperation"
    }

}

private extension URLSessionTaskTests {

    func makeTask(headers: [String: String], body: String?) -> URLSessionTask {
        var request = URLRequest(url: URL(string: "https://anything.com")!)
        request.httpBody = body?.data(using: .utf8)
        request.allHTTPHeaderFields = headers
        return URLSession(configuration: .ephemeral).dataTask(with: request)
    }

}
