import XCTest

class SentryTransactionTests: XCTestCase {
    
    private class Fixture {
        static var transaction: Transaction {
            let span = SentrySpan(context: SpanContext(operation: "some"))
            return Transaction(trace: span, children: [])
        }
    }

    func testSerializeMeasurements_NoMeasurements() {
        let actual = Fixture.transaction.serialize()
        
        XCTAssertNil(actual["measurements"])
    }
    
    func testSerializeMeasurements_Measurements() {
        let transaction = Fixture.transaction
        
        let appStart = ["value": 15_000.0]
        transaction.setMeasurementValue(appStart, forKey: "app_start_cold")
        let actual = transaction.serialize()
        
        let actualMeasurements = actual["measurements"] as? [String: [String: Double]]
        XCTAssertEqual(appStart, actualMeasurements?["app_start_cold"] )
    }
    
    func testSerializeMeasurements_GarbageInMeasurements_GarbageSanitized() {
        let transaction = Fixture.transaction
        
        let appStart = ["value": self]
        transaction.setMeasurementValue(appStart, forKey: "app_start_cold")
        let actual = transaction.serialize()
        
        let actualMeasurements = actual["measurements"] as? [String: [String: String]]
        XCTAssertEqual(["value": self.description], actualMeasurements?["app_start_cold"] )
    }
}
