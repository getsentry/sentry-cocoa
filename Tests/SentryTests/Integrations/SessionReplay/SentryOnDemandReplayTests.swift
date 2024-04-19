import Foundation
import Nimble
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentryOnDemandReplayTests: XCTestCase {
    
    func testAddFrame() {
        let outputPath = FileManager.default.temporaryDirectory
        let sut = SentryOnDemandReplay(outputPath: outputPath.path)
        
    }
    
}
#endif
