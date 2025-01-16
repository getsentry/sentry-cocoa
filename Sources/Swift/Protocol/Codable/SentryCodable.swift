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
