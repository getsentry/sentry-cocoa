/**
 * This is a partial implementation of the MessagePack format.
 * We only need to concatenate a list of NSData into an envelope item.
 */
class SentryMsgPackSerializer {
    @objc
    static func serializeDictionary(toMessagePack dictionary: [String: Any], intoFile fileURL: URL) -> Bool {
        do {
            let data = try serializeDictionaryToMessagePack(dictionary)
            try data.write(to: fileURL)
            return true
        } catch {
            SentrySDKLog.error("Failed to serialize dictionary to MessagePack or write to file - Error: \(error)")
            return false
        }
    }

    static func serializeDictionaryToMessagePack(_ dictionary: [String: Any]) throws -> Data { // swiftlint:disable:this function_body_length
        let outputStream = OutputStream.toMemory()
        outputStream.open()
        defer { outputStream.close() }
        
        let mapHeader = UInt8(0x80 | dictionary.count) // Map up to 15 elements
        _ = outputStream.write([mapHeader], maxLength: 1)

        for (key, anyValue) in dictionary {
            guard let value = anyValue as? SentryStreamable else {
                throw SentryMsgPackSerializerError.invalidValue("Value does not conform to SentryStreamable: \(anyValue)")
            }
            guard let keyData = key.data(using: .utf8) else {
                throw SentryMsgPackSerializerError.invalidInput("Could not encode key as UTF-8: \(key)")
            }
            
            let str8Header: UInt8 = 0xD9 // String up to 255 characters
            let keyLength = UInt8(truncatingIfNeeded: keyData.count) // Truncates if > 255, matching Objective-C behavior
            _ = outputStream.write([str8Header], maxLength: 1)
            _ = outputStream.write([keyLength], maxLength: 1)
            
            keyData.withUnsafeBytes { bytes in
                guard let bufferAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
                    throw SentryMsgPackSerializerError.invalidInput("Could not get buffer address for key: \(key)")
                }
                _ = outputStream.write(bufferAddress, maxLength: keyData.count)
            }

            let dataLength = value.streamSize()
            if dataLength <= 0 {
                // MsgPack is being used strictly for session replay.
                // An item with a length of 0 will not be useful.
                // If we plan to use MsgPack for something else,
                // this needs to be re-evaluated.
                SentrySDKLog.error("Data for MessagePack dictionary has no content - Input: \(value)")
                throw SentryMsgPackSerializerError.emptyData("Empty data for MessagePack dictionary")
            }

            let valueLength = UInt32(truncatingIfNeeded: dataLength)
            // We will always use the 4 bytes data length for simplicity.
            // Worst case we're losing 3 bytes.
            let bin32Header: UInt8 = 0xC6
            _ = outputStream.write([bin32Header], maxLength: 1)
            
            // Write UInt32 as big endian bytes
            let lengthBytes = [
                UInt8((valueLength >> 24) & 0xFF),
                UInt8((valueLength >> 16) & 0xFF),
                UInt8((valueLength >> 8) & 0xFF),
                UInt8(valueLength & 0xFF)
            ]
            _ = outputStream.write(lengthBytes, maxLength: 4)

            guard let inputStream = value.asInputStream() else {
                SentrySDKLog.error("Could not get input stream - Input: \(value)")
                throw SentryMsgPackSerializerError.streamError("Could not get input stream from value")
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
                    SentrySDKLog.error("Error reading bytes from input stream - Input: \(value) - \(bytesRead)")
                    throw SentryMsgPackSerializerError.streamError("Error reading bytes from input stream")
                }
            }
        }

        guard let data = outputStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
            throw SentryMsgPackSerializerError.outputError("Could not retrieve data from memory stream")
        }
        
        return data
    }
}
