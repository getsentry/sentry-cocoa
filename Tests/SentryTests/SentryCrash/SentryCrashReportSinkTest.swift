import XCTest

class SentryCrashReportSinkTests: SentrySDKIntegrationTestsBase {
        
    func testFilterReports_withScreenShots() {
        givenSdkWithHub()
        
        let reportSink = SentryCrashReportSink(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []))
        let expect = expectation(description: "Callback Called")
        
        let report = ["screenshots":["file.png"]];
        
        reportSink.filterReports([report]) { reports, completed, error in
            self.assertCrashEventWithScope { event, scope in
                XCTAssertEqual(scope?.attachments.count, 1)
                expect.fulfill()
            }
        }
                
        wait(for: [expect], timeout: 1)
    }
    
    func testFilterReports_CopyHubScope() {
        givenSdkWithHub()
        SentrySDK.currentHub().scope.setEnvironment("testFilterReports_CopyHubScope")
        
        let reportSink = SentryCrashReportSink(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []))
        let expect = expectation(description: "Callback Called")
        
        let report = [String:Any]();
        
        reportSink.filterReports([report]) { reports, completed, error in
            self.assertCrashEventWithScope { event, scope in
                let data = scope?.serialize()
                XCTAssertEqual(data?["environment"] as? String, "testFilterReports_CopyHubScope")
                expect.fulfill()
            }
        }
                
        wait(for: [expect], timeout: 1)
    }
}
