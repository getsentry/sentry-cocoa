import Foundation
import XCTest

extension XCTest {
    func contentsOfResource(_ resource: String, ofType: String = "json") throws -> Data {
        let path = Bundle(for: type(of: self)).path(forResource: "Resources/\(resource)", ofType: "json")
        return try Data(contentsOf: URL(fileURLWithPath: path ?? ""))
    }
}
