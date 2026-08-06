import XCTest

extension XCTestCase {
    
    private func jsonDataOfResource(resource: String) throws -> Data {
        let jsonPath = Bundle(for: type(of: self)).path(forResource: resource, ofType: "json")
        return try Data(contentsOf: URL(fileURLWithPath: jsonPath ?? ""))
    }
    
#if !SENTRY_DISABLE_SENTRYCRASH_V10
    func givenStoredSentryCrashReport(resource: String) throws {
        let jsonData = try jsonDataOfResource(resource: resource)
        jsonData.withUnsafeBytes { ( bytes: UnsafeRawBufferPointer) in
            let pointer = bytes.bindMemory(to: Int8.self)
            sentrycrashcrs_addUserReport(pointer.baseAddress, Int32(jsonData.count))
        }
    }
#endif
    
    func getCrashReport(resource: String) throws -> [String: Any] {
        let jsonData = try jsonDataOfResource(resource: resource)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])
    }
}
