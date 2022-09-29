import XCTest

extension XCTestCase {
    func givenStoredSentryCrashReport(resource: String) throws {
        let jsonPath = Bundle(for: type(of: self)).path(forResource: resource, ofType: "json")
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath ?? ""))
        jsonData.withUnsafeBytes { ( bytes: UnsafeRawBufferPointer) -> Void in
            let pointer = bytes.bindMemory(to: Int8.self)
            sentrycrashcrs_addUserReport(pointer.baseAddress, Int32(jsonData.count))
        }
    }
}
