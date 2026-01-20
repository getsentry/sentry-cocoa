// swiftlint:disable missing_docs
import Foundation

@objcMembers
@_spi(Private) public class SentryEventDecoder: NSObject {
    public static func decodeEvent(jsonData: Data) -> Event? {
        return decodeFromJSONData(jsonData: jsonData) as SentryEventDecodable?
    }
}
// swiftlint:enable missing_docs
