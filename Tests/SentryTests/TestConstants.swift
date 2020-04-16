import XCTest

struct TestConstants {
    static let dsnAsString: NSString = "https://username:password@app.getsentry.com/12345"

    static var dsn: SentryDsn {
        var dsn: SentryDsn?
        do {
            dsn = try SentryDsn(string: self.dsnAsString as String)
        } catch {
            XCTFail("SentryDsn could not be created")
        }
        
        return dsn!
    }
}
