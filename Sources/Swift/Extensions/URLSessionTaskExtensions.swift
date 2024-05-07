import Foundation

public extension URLSessionTask {

    @objc
    func getGraphQLOperationName() -> String? {
        guard originalRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json" else { return nil }
        guard let requestBody = originalRequest?.httpBody else { return nil }

        let requestInfo = try? JSONDecoder().decode(GraphQLRequest.self, from: requestBody)

        return requestInfo?.operationName
    }

}

private struct GraphQLRequest: Decodable {
    let operationName: String
}
