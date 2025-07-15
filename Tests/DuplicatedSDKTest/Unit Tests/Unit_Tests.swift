import Foundation
import Sentry
import XCTest

final class TestLog: XCTestCase {
    func testDuplicatedLoadMessageOnSDKInit() throws {

        let output = captureStandardOutput {
            let options = Options()
            options.debug = true
            options.diagnosticLevel = .warning
            SentrySDK.start(options: options)
            
            // Force loading another library to trigger validation
            let path = Bundle(for: type(of: self)).bundlePath
            let fullpath = "\(path)/../../Frameworks/ModuleA.framework/ModuleA"
            guard dlopen(fullpath, RTLD_NOW) != nil else {
                let error = String(cString: dlerror())
                fatalError("Could not open framework: \(error)")
            }
            
            // Unfortunately, there is no other option rather than wait a couple seconds.
            // If this test becomes flaky, we will disable it
            sleep(10)
        }
        
        XCTAssertTrue(output.contains("Sentry SDK was loaded multiple times in the binary"))
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
