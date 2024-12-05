import XCTest

class SentryMetaTests: XCTestCase {

    override func tearDown() {
        SentryMeta.clearSdkPackages()
    }

    func testPackagesAreNotNil() {
        let packages = SentryMeta.getSdkPackages()
        XCTAssertNotNil(packages)
        XCTAssertEqual(0, packages.count)
    }

    func testPackagesIncludeSdkPackage() {
        SentrySdkPackage.setSentryPackageInfoForTests(0) //SPM

        let packages = SentryMeta.getSdkPackages()
        XCTAssertEqual(1, packages.count)

        let package = packages.first!
        XCTAssertEqual("spm:getsentry/sentry.cocoa", package.name)
        XCTAssertEqual(SentryMeta.versionString, package.version)
    }

}
