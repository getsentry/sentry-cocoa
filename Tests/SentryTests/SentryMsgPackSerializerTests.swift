import Foundation
@testable import Sentry
import XCTest

// Configurable test object for simulating different SentryStreamable behaviors
class TestStreamableObject: NSObject, SentryStreamable {
    
    private let shouldReturnNilInputStream: Bool
    private let streamSizeValue: Int
    private let shouldReturnErrorStream: Bool
    
    init(streamSize: Int, shouldReturnNilInputStream: Bool, shouldReturnErrorStream: Bool = false) {
        self.streamSizeValue = streamSize
        self.shouldReturnNilInputStream = shouldReturnNilInputStream
        self.shouldReturnErrorStream = shouldReturnErrorStream
        super.init()
    }
    
    func asInputStream() -> InputStream? {
        if shouldReturnNilInputStream {
            return nil
        }
        if shouldReturnErrorStream {
            return ErrorInputStream()
        }
        return InputStream(data: Data())
    }
    
    func streamSize() -> Int {
        return streamSizeValue
    }
    
    // MARK: - Convenience factory methods for common test scenarios
    
    static func objectWithNilInputStream() -> TestStreamableObject {
        return TestStreamableObject(streamSize: 10, shouldReturnNilInputStream: true)
    }
    
    static func objectWithZeroSize() -> TestStreamableObject {
        return TestStreamableObject(streamSize: 0, shouldReturnNilInputStream: false)
    }
    
    static func objectWithNegativeSize() -> TestStreamableObject {
        return TestStreamableObject(streamSize: -1, shouldReturnNilInputStream: false)
    }
    
    static func objectWithErrorStream() -> TestStreamableObject {
        return TestStreamableObject(streamSize: 10, shouldReturnNilInputStream: false, shouldReturnErrorStream: true)
    }
}

// Custom InputStream that always returns an error when read
class ErrorInputStream: InputStream {
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

class SentryMsgPackSerializerTests: XCTestCase {
    
    func testSerializeNSData() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let dictionary: [String: SentryStreamable] = [
            "key1": Data("Data 1".utf8) as SentryStreamable,
            "key2": Data("Data 2".utf8) as SentryStreamable
        ]
        
        defer {
            do {
                try FileManager.default.removeItem(at: tempFileURL)
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertTrue(result)
        let tempFile = try Data(contentsOf: tempFileURL)
        assertMsgPack(tempFile)
    }
    
    func testSerializeURL() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let file1URL = tempDirectoryURL.appendingPathComponent("file1.dat")
        let file2URL = tempDirectoryURL.appendingPathComponent("file2.dat")
        
        defer {
            do {
                try FileManager.default.removeItem(at: tempFileURL)
                try FileManager.default.removeItem(at: file1URL)
                try FileManager.default.removeItem(at: file2URL)
            } catch {
                XCTFail("Failed to cleanup temp files: \(error)")
            }
        }
        
        try "File 1".write(to: file1URL, atomically: true, encoding: .utf8)
        try "File 2".write(to: file2URL, atomically: true, encoding: .utf8)
        
        let dictionary: [String: SentryStreamable] = [
            "key1": file1URL as SentryStreamable,
            "key2": file2URL as SentryStreamable
        ]
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertTrue(result)
        let tempFile = try Data(contentsOf: tempFileURL)
        assertMsgPack(tempFile)
    }
    
    func testSerializeInvalidFile() {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let nonExistentFileURL = tempDirectoryURL.appendingPathComponent("notAFile.dat")
        let dictionary: [String: SentryStreamable] = ["key1": nonExistentFileURL as SentryStreamable]
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertFalse(result)
    }
    
    func testSerializeNilInputStream() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let nilStreamObject = TestStreamableObject.objectWithNilInputStream()
        let dictionary: [String: SentryStreamable] = ["key1": nilStreamObject as SentryStreamable]
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertFalse(result)
    }
    
    func testSerializeZeroSizeStream() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let zeroSizeObject = TestStreamableObject.objectWithZeroSize()
        let dictionary: [String: SentryStreamable] = ["key1": zeroSizeObject as SentryStreamable]
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertFalse(result)
    }
    
    func testSerializeNegativeSizeStream() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let negativeSizeObject = TestStreamableObject.objectWithNegativeSize()
        let dictionary: [String: SentryStreamable] = ["key1": negativeSizeObject as SentryStreamable]
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertFalse(result)
    }
    
    func testSerializeURLWithNilPath() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        // Create a URL that has a nil path (e.g., a URL with just a scheme but no path component)
        let nilPathURL = URL(string: "data:")!
        let dictionary: [String: SentryStreamable] = ["key1": nilPathURL as SentryStreamable]
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertFalse(result)
    }
    
    func testSerializeEmptyDictionary() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let dictionary: [String: SentryStreamable] = [:]
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertTrue(result)
        let tempFile = try Data(contentsOf: tempFileURL)
        // Verify empty dictionary is serialized as map header with count 0
        XCTAssertEqual(tempFile.count, 1)
        XCTAssertEqual(tempFile[0], 0x80) // Map with 0 elements
    }
    
    func testSerializeSingleElement() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let dictionary: [String: SentryStreamable] = [
            "key": Data("test data".utf8) as SentryStreamable
        ]
        
        defer {
            do {
                try FileManager.default.removeItem(at: tempFileURL)
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertTrue(result)
        let tempFile = try Data(contentsOf: tempFileURL)
        assertMsgPack(tempFile)
    }
    
    func testSerializeLargeDictionary() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        
        // Create dictionary with 16 elements (beyond the 15 element limit)
        var dictionary: [String: SentryStreamable] = [:]
        for i in 0..<16 {
            dictionary["key\(i)"] = Data("data\(i)".utf8) as SentryStreamable
        }
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        // Maintains Objective-C behavior: allows large dictionaries but header will overflow
        XCTAssertTrue(result)
        let tempFile = try Data(contentsOf: tempFileURL)
        XCTAssertGreaterThan(tempFile.count, 1)
        XCTAssertEqual(tempFile[0], 0x90) // Map header with overflow: 0x80 | 16 = 0x90
    }
    
    func testSerializeLongKey() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        
        // Create a key longer than 255 characters
        let longKey = String(repeating: "a", count: 300)
        let dictionary: [String: SentryStreamable] = [
            longKey: Data("test data".utf8) as SentryStreamable
        ]
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        // Maintains Objective-C behavior: allows long keys but length will be truncated to uint8_t
        XCTAssertTrue(result)
        let tempFile = try Data(contentsOf: tempFileURL)
        XCTAssertGreaterThan(tempFile.count, 1)
    }
    
    func testSerializeMaxLengthKey() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        
        // Create a key exactly at 255 characters (the maximum allowed)
        let maxKey = String(repeating: "a", count: 255)
        let dictionary: [String: SentryStreamable] = [
            maxKey: Data("test data".utf8) as SentryStreamable
        ]
        
        defer {
            do {
                try FileManager.default.removeItem(at: tempFileURL)
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        // Keys exactly at 255 bytes should work fine
        XCTAssertTrue(result)
        let tempFile = try Data(contentsOf: tempFileURL)
        assertMsgPack(tempFile)
    }
    
    func testSerializeToInvalidPath() throws {
        // Arrange
        let invalidPath = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/test.dat")
        let dictionary: [String: SentryStreamable] = [
            "key": Data("test data".utf8) as SentryStreamable
        ]
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: invalidPath)
        
        // Assert
        // NOTE: Objective-C implementation doesn't validate if NSOutputStream opened successfully
        // Swift implementation uses data.write(to:) which properly validates paths
        // This is an improvement over Objective-C behavior
        XCTAssertFalse(result)
    }
    
    func testSerializeStreamReadError() throws {
        // Arrange
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("test.dat")
        let errorStreamObject = TestStreamableObject.objectWithErrorStream()
        let dictionary: [String: SentryStreamable] = ["key1": errorStreamObject as SentryStreamable]
        
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
            } catch {
                XCTFail("Failed to cleanup temp file: \(error)")
            }
        }
        
        // Act
        let result = SentryMsgPackSerializer.serializeDictionary(toMessagePack: dictionary, intoFile: tempFileURL)
        
        // Assert
        XCTAssertFalse(result)
    }
    
    // MARK: - Helper Methods
    
    private func assertMsgPack(_ data: Data) {
        // Arrange
        let stream = InputStream(data: data)
        stream.open()
        defer { stream.close() }
        
        var buffer = [UInt8](repeating: 0, count: 1_024)
        
        // Assert: Validate dictionary header
        stream.read(&buffer, maxLength: 1)
        XCTAssertEqual(buffer[0] & 0x80, 0x80) // Assert data is a dictionary
        let dicSize = buffer[0] & 0x0F // Gets dictionary length
        
        // Assert: Validate each dictionary entry
        for _ in 0..<dicSize {
            // Validate key format (string up to 255 characters)
            stream.read(&buffer, maxLength: 1)
            XCTAssertEqual(buffer[0], 0xD9) // Asserts key is a string of up to 255 characters
            
            // Validate key length and content
            stream.read(&buffer, maxLength: 1)
            let stringLen = buffer[0] // Gets string length
            let bytesRead = stream.read(&buffer, maxLength: Int(stringLen)) // read the key from the buffer
            buffer[bytesRead] = 0 // append a null terminator to the string
            let key = String(cString: buffer)
            XCTAssertEqual(key.count, Int(stringLen))
            
            // Validate value format (binary data)
            stream.read(&buffer, maxLength: 1)
            XCTAssertEqual(buffer[0], 0xC6) // Binary data format marker
            stream.read(&buffer, maxLength: MemoryLayout<UInt32>.size)
            let dataLen = buffer.withUnsafeBytes { bytes in
                bytes.load(as: UInt32.self).bigEndian
            }
            stream.read(&buffer, maxLength: Int(dataLen)) // Read the actual data
        }
        
        // Assert: Stream should be fully consumed
        let isEndOfFile = stream.read(&buffer, maxLength: 1)
        XCTAssertEqual(isEndOfFile, 0) // Should be at end of stream
    }
}
