import Foundation

@objcMembers
public class SentryEventDecoder: NSObject {
    static func decodeEvent(jsonData: Data) -> Event? {
        return decodeFromJSONData(jsonData: jsonData) as SentryEventDecodable?
    }
}
