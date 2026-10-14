// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public final class URLSessionTaskHelper: NSObject {

    public static func getGraphQLOperationName(from task: URLSessionTask?) -> String? {
        guard let request = task?.unbridgedOriginalRequest else { return nil }
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json" else { return nil }
        guard let requestBody = request.httpBody else { return nil }

        let requestInfo = try? JSONDecoder().decode(GraphQLRequest.self, from: requestBody)

        return requestInfo?.operationName
    }

}

extension URLSessionTask {
    /// The task's `originalRequest` object.
    ///
    /// Reading `originalRequest` in Swift bridges it to a `URLRequest`, which copies the request
    /// without synchronizing with threads that write into it. See ``SentryURLSessionTaskRequest``.
    var unbridgedOriginalRequest: NSURLRequest? {
        SentryURLSessionTaskRequest.originalRequest(of: self) as? NSURLRequest
    }

    /// The task's `currentRequest` object, without bridging it to a `URLRequest` copy.
    var unbridgedCurrentRequest: NSURLRequest? {
        SentryURLSessionTaskRequest.currentRequest(of: self) as? NSURLRequest
    }
}

private struct GraphQLRequest: Decodable {
    let operationName: String
}
// swiftlint:enable missing_docs
