import Sentry
import XCTest

final class TestLog: XCTestCase {
    func testDuplicatedLoadMessageOnSDKInit() throws {

        let output = captureStandardOutput {
          SentrySDK.start(options: Options())
        }
        
        XCTAssertTrue(output.contains("❌ Sentry SDK was loaded multiple times in the binary ❌"))
    }
  
    private func captureStandardOutput(_ action: () -> Void) -> String {
        let pipe = Pipe()
        let originalStdOut = dup(fileno(stdout))

        dup2(pipe.fileHandleForWriting.fileDescriptor, fileno(stdout))

        action()

        fflush(stdout)
        dup2(originalStdOut, fileno(stdout))
        close(originalStdOut)

        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        pipe.fileHandleForReading.closeFile()

        return String(data: data, encoding: .utf8) ?? ""
    }
}
