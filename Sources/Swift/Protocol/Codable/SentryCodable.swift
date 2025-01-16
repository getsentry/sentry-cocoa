import Foundation

func decodeFromJSONData<T: Decodable>(jsonData: Data) -> T? {
    if jsonData.isEmpty {
        return nil
    }
    
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: jsonData)
    } catch {
        SentryLog.error("Could not decode object of type \(T.self) from JSON data due to error: \(error)")
        return nil
    }
}

/// Warning: Use this method sparingly cause it adds a performance overhead. Therefore, it has the verbose method name.
///
/// Ideally, we should implement the KeyedEncodingContainerProtocol to encode directly into a
/// dictionary instead of first encoding to Data and then into a dictionary. The SDK will use Swifts
/// Codable to serialize its classes directly to Data and skip the conversion to a dictionary in the future.
/// Once we switch to complete Codeable serialization, we can drop the public SentrySerializable protocol.
/// It would be acceptable to keep this method for backward compatibility so we don't have to do the
/// conversion in a major version.
/// It is also acceptable to use this method to serialize small classes without dependencies on other
/// serializable classes such as SentryGeo.
func addsPerformanceOverhead_serializeToJSONObject<T: Encodable>(_ value: T) -> [String: Any] {
    let encoder = JSONEncoder()

    do {
        let jsonData = try encoder.encode(value)
        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            return jsonObject
        }
    } catch {
        SentryLog.error("Could not serialize object \(value) to JSON due to error: \(error)")
    }
    
    return [:]
    
}
