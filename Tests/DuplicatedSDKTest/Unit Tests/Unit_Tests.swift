import Foundation
import Sentry
import XCTest

final class TestLog: XCTestCase {
    private var pipe: Pipe?
    private var originalStdOut: Int32?
    private var capturedOutput = ""
    private var isCapturing = false
    
    override func tearDown() {
        stopCapturingOutput()
        super.tearDown()
    }
    
    func testDuplicatedLoadMessageOnSDKInit() throws {
        let expectation = XCTestExpectation(description: "Wait for duplicated SDK load message")
        
        capturedOutput = ""
        startCapturingOutput()
        
        // Initialize Sentry SDK
        let options = Options()
        options.debug = true
        options.diagnosticLevel = .debug
        SentrySDK.start(options: options)
        
        // Force loading another library to trigger validation
        let path = Bundle(for: type(of: self)).bundlePath
        let fullpath = "\(path)/../../Frameworks/ModuleA.framework/ModuleA"
        guard dlopen(fullpath, RTLD_NOW) != nil else {
            let error = String(cString: dlerror())
            XCTFail("Could not open framework: \(error)")
            return
        }
        
        // Check for the message periodically
        let checkQueue = DispatchQueue(label: "message.check")
        checkQueue.async {
            while self.isCapturing {
                if self.capturedOutput.contains("Sentry SDK was loaded multiple times in the binary") {
                    expectation.fulfill()
                    break
                }
                Thread.sleep(forTimeInterval: 0.1) // Check every 100ms
            }
        }
        
        // This expectation is fulfilled immediately on a mac, but takes way longer on CI
        wait(for: [expectation], timeout: 600.0)
        
        XCTAssertTrue(capturedOutput.contains("Sentry SDK was loaded multiple times in the binary"))
    }
    
    private func startCapturingOutput() {
        pipe = Pipe()
        originalStdOut = dup(fileno(stdout))
        
        guard let pipe = pipe else {
            XCTFail("Failed to setup output capture")
            return
        }
        
        dup2(pipe.fileHandleForWriting.fileDescriptor, fileno(stdout))
        isCapturing = true
        
        // Start reading from pipe in background
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.capturedOutput += output
                }
            }
        }
    }
    
    private func stopCapturingOutput() {
        guard let pipe = pipe, let originalStdOut = originalStdOut else { return }
        
        isCapturing = false
        pipe.fileHandleForReading.readabilityHandler = nil
        
        fflush(stdout)
        dup2(originalStdOut, fileno(stdout))
        close(originalStdOut)
        
        pipe.fileHandleForWriting.closeFile()
        pipe.fileHandleForReading.closeFile()
        
        self.pipe = nil
        self.originalStdOut = nil
    }
}
