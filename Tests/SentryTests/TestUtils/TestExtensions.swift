import Foundation
import XCTest

extension TimeInterval {
    func toNanoSeconds() -> UInt64 {
        return UInt64(self * Double(NSEC_PER_SEC))
    }
}

extension UInt64 {
    func toTimeInterval() -> TimeInterval {
        return Double(self) / Double(NSEC_PER_SEC)
    }
}

extension XCTest {
    func contentsOfResource(_ resource: String, ofType: String = "json") throws -> Data {
        let path = Bundle(for: type(of: self)).path(forResource: "Resources/\(resource)", ofType: "json")
        return try Data(contentsOf: URL(fileURLWithPath: path ?? ""))
    }
}
