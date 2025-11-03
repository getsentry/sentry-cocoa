/**
 * This is a partial implementation of the MessagePack format.
 * We only need to concatenate a list of NSData into an envelope item.
 */
final class SentryMsgPackSerializer {
    static func serializeDictionary(toMessagePack dictionary: [String: SentryStreamable], intoFile fileURL: URL) -> Bool {
        do {
            try serializeToFile(dictionary: dictionary, fileURL: fileURL)
            return true
        } catch {
            SentrySDKLog.error("Failed to serialize dictionary to MessagePack - Error: \(error)")
            // Clean up partial file on error
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                // Ignore cleanup errors - file might not exist
            }
            return false
        }
    }
    
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private static func serializeToFile(dictionary: [String: SentryStreamable], fileURL: URL) throws {
        guard let outputStream = OutputStream(url: fileURL, append: false) else {
            throw SentryMsgPackSerializerError.outputError("Failed to create output stream for file: \(fileURL)")
        }
        outputStream.open()
        defer { 
            outputStream.close()
        }
        
        // Check if stream opened successfully
        if outputStream.streamError != nil {
            throw SentryMsgPackSerializerError.outputError("Failed to open output stream for file: \(fileURL)")
        }
        
        let mapHeader = UInt8(truncatingIfNeeded: 0x80 | dictionary.count) // Map up to 15 elements
        _ = outputStream.write([mapHeader], maxLength: 1)

        for (key, value) in dictionary {
            let keyData = Data(key.utf8)
            
            let str8Header: UInt8 = 0xD9 // String up to 255 characters
            let keyLength = UInt8(truncatingIfNeeded: keyData.count) // Truncates if > 255, matching Objective-C behavior
            _ = outputStream.write([str8Header], maxLength: 1)
            _ = outputStream.write([keyLength], maxLength: 1)
            
            keyData.withUnsafeBytes { bytes in
                guard let bufferAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }
                _ = outputStream.write(bufferAddress, maxLength: keyData.count)
            }

            guard let dataLength = value.streamSize(), dataLength > 0 else {
                // MsgPack is being used strictly for session replay.
                // An item with a length of 0 will not be useful.
                // If we plan to use MsgPack for something else,
                // this needs to be re-evaluated.
                throw SentryMsgPackSerializerError.emptyData("Data for MessagePack dictionary has no content - Input: \(value)")
            }

            var valueLength = UInt32(truncatingIfNeeded: dataLength)
            // We will always use the 4 bytes data length for simplicity.
            // Worst case we're losing 3 bytes.
            let bin32Header: UInt8 = 0xC6
            _ = outputStream.write([bin32Header], maxLength: 1)
            
            // Write UInt32 as big endian bytes
            valueLength = NSSwapHostIntToBig(valueLength)
            withUnsafeBytes(of: valueLength) { bytes in
                guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
                    return
                }
                _ = outputStream.write(baseAddress, maxLength: 4)
            }

            guard let inputStream = value.asInputStream() else {
                throw SentryMsgPackSerializerError.streamError("Could not get input stream - Input: \(value)")
            }
            
            inputStream.open()
            defer { inputStream.close() }

            var buffer = [UInt8](repeating: 0, count: 1_024)
            var bytesRead: Int

            while inputStream.hasBytesAvailable {
                bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
                if bytesRead > 0 {
                    _ = outputStream.write(buffer, maxLength: bytesRead)
                } else if bytesRead < 0 {
                    throw SentryMsgPackSerializerError.streamError("Error reading bytes from input stream - Input: \(value) - Bytes read: \(bytesRead)")
                }
            }
        }
    }
}
