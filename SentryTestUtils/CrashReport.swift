import XCTest

extension XCTestCase {
    
    func jsonDataOfResource(resource: String) throws -> Data {
        let jsonPath = Bundle(for: type(of: self)).path(forResource: resource, ofType: "json")
        return try Data(contentsOf: URL(fileURLWithPath: jsonPath ?? ""))
    }
    
    public func givenStoredSentryCrashReport(resource: String) throws {
        let jsonData = try jsonDataOfResource(resource: resource)
        jsonData.withUnsafeBytes { ( bytes: UnsafeRawBufferPointer) -> Void in
            let pointer = bytes.bindMemory(to: Int8.self)
            sentrycrashcrs_addUserReport(pointer.baseAddress, Int32(jsonData.count))
        }
    }
    
    public func getCrashReport(resource: String) throws -> [String: Any] {
        let jsonData = try jsonDataOfResource(resource: resource)
        return try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
    }
}
