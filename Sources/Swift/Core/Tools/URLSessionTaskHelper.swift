// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public final class URLSessionTaskHelper: NSObject {

    public static func getGraphQLOperationName(from task: URLSessionTask?) -> String? {
        guard let task, let request = SentryURLRequestWrapper(originalRequestOf: task) else { return nil }
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json" else { return nil }
        guard let requestBody = request.httpBody else { return nil }

        let requestInfo = try? JSONDecoder().decode(GraphQLRequest.self, from: requestBody)

        return requestInfo?.operationName
    }

}

private struct GraphQLRequest: Decodable {
    let operationName: String
}
// swiftlint:enable missing_docs
