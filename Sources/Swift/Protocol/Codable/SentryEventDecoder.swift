@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryEventDecoder: NSObject {
    public static func decodeEvent(jsonData: Data) -> Event? {
        return decodeFromJSONData(jsonData: jsonData) as SentryEventDecodable?
    }
}
