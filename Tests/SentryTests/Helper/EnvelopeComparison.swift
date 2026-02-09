import XCTest

extension XCTest {
    func compareEnvelopes(_ expectedEnvelope: Data?, _ actualEnvelope: Data?, message: String) throws {
        
        enum EnvelopeData: Equatable {
            case dictionary(NSDictionary)
            case string(String)
        }
        
        guard let expectedEnvelope, let actualEnvelope else {
            XCTAssertEqual(expectedEnvelope, actualEnvelope, message)
            return
        }
        
        guard let unzippedExpected = sentry_unzippedData(expectedEnvelope), let unzippedActual = sentry_unzippedData(actualEnvelope) else {
            XCTFail(message)
            return
        }
        
        let newline = Data("\n".utf8)
        let expectedElements = unzippedExpected.backwardCompatibleSplit(separator: newline)
        let actualElements = unzippedActual.backwardCompatibleSplit(separator: newline)
        let expectedData = try expectedElements.map { data -> EnvelopeData in
            // swiftlint:disable:next no_try_optional_in_tests
            if let json = try? JSONSerialization.jsonObject(with: data) as? NSDictionary {
                return .dictionary(json)
            }
            let dataAsString = try XCTUnwrap(String(data: data, encoding: .utf8))
            return .string(dataAsString)
        }
        let actualData = try actualElements.map { data -> EnvelopeData in
            // swiftlint:disable:next no_try_optional_in_tests
            if let json = try? JSONSerialization.jsonObject(with: data) as? NSDictionary {
                return .dictionary(json)
            }
            let dataAsString = try XCTUnwrap(String(data: data, encoding: .utf8))
            return .string(dataAsString)
        }
        XCTAssertEqual(expectedData, actualData, message)
    }
}

import Foundation

extension Data {
    // Used to support iOS < 16.0
    func backwardCompatibleSplit(separator: Data) -> [Data] {
        // When the `split` function is available all we need to do is call it.
        if #available(iOS 16.0, tvOS 16.0, watchOS 16.0, macOS 13.0, *) {
            return split(separator: separator)
        }

        guard !separator.isEmpty else { return [self] }
        
        var parts: [Data] = []
        var searchRange: Range<Data.Index> = startIndex..<endIndex
        var lastIndex = startIndex
        
        while let range = self.range(of: separator, options: [], in: searchRange) {
            parts.append(self[lastIndex..<range.lowerBound])
            searchRange = range.upperBound..<endIndex
            lastIndex = range.upperBound
        }
        
        if lastIndex != endIndex {
            parts.append(self[lastIndex..<endIndex])
        } else if self.count >= separator.count &&
                  self[self.count - separator.count..<self.count] == separator {
            parts.append(Data())
        }
        
        return parts
    }
}
