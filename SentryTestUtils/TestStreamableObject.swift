@testable import Sentry

private class ErrorInputStream: InputStream {
    override var hasBytesAvailable: Bool {
        return true
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        return -1 // Simulate read error
    }

    override func open() {
        // No-op
    }

    override func close() {
        // No-op
    }
}

public class TestStreamableObject: NSObject, SentryStreamable {

    private let shouldReturnNilInputStream: Bool
    private let streamSizeValue: Int
    private let shouldReturnErrorStream: Bool

    public init(streamSize: Int, shouldReturnNilInputStream: Bool, shouldReturnErrorStream: Bool = false) {
        self.streamSizeValue = streamSize
        self.shouldReturnNilInputStream = shouldReturnNilInputStream
        self.shouldReturnErrorStream = shouldReturnErrorStream
        super.init()
    }

    public func asInputStream() -> InputStream? {
        if shouldReturnNilInputStream {
            return nil
        }
        if shouldReturnErrorStream {
            return ErrorInputStream()
        }
        return InputStream(data: Data())
    }

    public func streamSize() -> Int {
        return streamSizeValue
    }

    // MARK: - Convenience factory methods for common test scenarios

    public static func objectWithNilInputStream() -> TestStreamableObject {
        return TestStreamableObject(streamSize: 10, shouldReturnNilInputStream: true)
    }

    public static func objectWithZeroSize() -> TestStreamableObject {
        return TestStreamableObject(streamSize: 0, shouldReturnNilInputStream: false)
    }

    public static func objectWithNegativeSize() -> TestStreamableObject {
        return TestStreamableObject(streamSize: -1, shouldReturnNilInputStream: false)
    }

    public static func objectWithErrorStream() -> TestStreamableObject {
        return TestStreamableObject(streamSize: 10, shouldReturnNilInputStream: false, shouldReturnErrorStream: true)
    }

    public static func objectWithZeroBytesRead() -> TestStreamableObject {
        return TestStreamableObject(streamSize: 10, shouldReturnNilInputStream: false, shouldReturnErrorStream: false)
    }

    public static func objectWithLargeSize() -> TestStreamableObject {
        // Return size larger than UInt32.max to test truncation
        return TestStreamableObject(streamSize: Int(UInt32.max) + 1_000, shouldReturnNilInputStream: false, shouldReturnErrorStream: false)
    }
}
