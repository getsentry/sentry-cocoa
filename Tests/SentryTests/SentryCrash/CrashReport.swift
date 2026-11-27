import SentryTestUtilsObjC
import XCTest

extension XCTestCase {
    
    private func jsonDataOfResource(resource: String) throws -> Data {
        let jsonPath = sentryTestResourceBundle(for: type(of: self)).path(forResource: resource, ofType: "json")
        return try Data(contentsOf: URL(fileURLWithPath: jsonPath ?? ""))
    }
    
    func getCrashReport(resource: String) throws -> [String: Any] {
        let jsonData = try jsonDataOfResource(resource: resource)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])
    }
}
