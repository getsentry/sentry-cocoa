@_implementationOnly import _SentryPrivate
import Foundation

/**
 * Driver class for capturing stdout and stderr output and forwarding it to Sentry logs.
 * This is used by SentryStdOutLogIntegration.
 */
@objc @_spi(Private) public class SentryStdOutLogIntegrationDriver: NSObject {
    private var stdErrPipe: Pipe?
    private var stdOutPipe: Pipe?
    private var originalStdOut: Int32 = -1
    private var originalStdErr: Int32 = -1
    
    private let logger: SentryLogger
    private let dispatchQueue: SentryDispatchQueueWrapper
    
    @objc(initWithDispatchQueue:logger:)
    @_spi(Private) public init(dispatchQueue: SentryDispatchQueueWrapper, logger: SentryLogger) {
        self.dispatchQueue = dispatchQueue
        self.logger = logger
        super.init()
    }
    
    @objc @_spi(Private) public func start() {
        originalStdOut = dup(fileno(stdout))
        originalStdErr = dup(fileno(stderr))
        
        configureSentrySDKLogToBypassPipe()
        
        stdOutPipe = duplicateFileDescriptor(fileno(stdout), isStderr: false)
        stdErrPipe = duplicateFileDescriptor(fileno(stderr), isStderr: true)
    }
    
    @objc @_spi(Private) public func stop() {
        // Restore SDK log print output
        
        SentrySDKLog.setOutput {
            print($0)
        }
        
        guard stdOutPipe != nil || stdErrPipe != nil else {
            return
        }
        
        // Restore original file descriptors
        
        if originalStdOut >= 0 {
            fflush(stdout)
            dup2(originalStdOut, fileno(stdout))
            close(originalStdOut)
            originalStdOut = -1
        }
        
        if originalStdErr >= 0 {
            fflush(stderr)
            dup2(originalStdErr, fileno(stderr))
            close(originalStdErr)
            originalStdErr = -1
        }
        
        // Clean up pipes
        
        stdOutPipe?.fileHandleForReading.readabilityHandler = nil
        stdOutPipe = nil
        
        stdErrPipe?.fileHandleForReading.readabilityHandler = nil
        stdErrPipe = nil
    }
    
    /// Write the input file descriptor to the input file handle, preserving the original output as well.
    /// This can be used to save stdout/stderr to a file while also keeping it on the console.
    private func duplicateFileDescriptor(_ fileDescriptor: Int32, isStderr: Bool) -> Pipe? {
        let pipe = Pipe()
        let newDescriptor = dup(fileDescriptor)
        let newFileHandle = FileHandle(fileDescriptor: newDescriptor, closeOnDealloc: true)
        
        if dup2(pipe.fileHandleForWriting.fileDescriptor, fileDescriptor) < 0 {
            SentrySDKLog.error("Unable to duplicate file descriptor \(fileDescriptor)")
            close(newDescriptor)
            return nil
        }
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            
            let data = handle.availableData
            self.dispatchQueue.dispatchAsync {
                self.handleLogData(data, isStderr: isStderr)
            }
            newFileHandle.write(data)
        }
        
        return pipe
    }
    
    // This way we do not produce loops by using SentrySDKLog during stdout log capture.
    private func configureSentrySDKLogToBypassPipe() {
        let fd = originalStdOut
        
        SentrySDKLog.setOutput { message in
            guard fd >= 0 else { return }
            
            // Append newline to match print() behavior
            let messageWithNewline = message + "\n"
            guard let data = messageWithNewline.data(using: .utf8) else {
                return
            }
            data.withUnsafeBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    write(fd, baseAddress, data.count)
                }
            }
        }
    }
    
    private func handleLogData(_ data: Data, isStderr: Bool) {
        guard data.count > 0,
              let logString = String(data: data, encoding: .utf8) else {
            return
        }
        
        let attributes: [String: Any] = [
            "sentry.log.source": isStderr ? "stderr" : "stdout"
        ]
        
        if isStderr {
            logger.warn(logString, attributes: attributes)
        } else {
            logger.info(logString, attributes: attributes)
        }
    }
}
