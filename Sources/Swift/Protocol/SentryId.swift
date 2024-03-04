import Foundation



@objcMembers
public class SentryId : NSObject {
    
    /**
     * A @c SentryId with an empty UUID "00000000000000000000000000000000".
     */
    static var empty = SentryId(UUIDString: "00000000-0000-0000-0000-000000000000")
    
    /**
     * Returns a 32 lowercase character hexadecimal string description of the @c SentryId, such as
     * "12c2d058d58442709aa2eca08bf20986".
     */
    var sentryIdString : String {
        return id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
    
    private let id : UUID
    
    /**
     * Creates a @c SentryId with a random UUID.
     */
    public override init() {
        id = UUID()
    }
    
    /**
     * Creates a SentryId with the given UUID.
     */
    public init(uuid: UUID) {
        id = uuid
    }
    
    /**
     * Creates a @c SentryId from a 32 character hexadecimal string without dashes such as
     * "12c2d058d58442709aa2eca08bf20986" or a 36 character hexadecimal string such as such as
     * "12c2d058-d584-4270-9aa2-eca08bf20986".
     * @return SentryId.empty for invalid strings.
     */
    public init?(UUIDString : String) {
        if let id = UUID(uuidString: UUIDString) {
            self.id = id
            return
        }
        
        if UUIDString.count != 32 {
            return nil
        }
        
        let dashedUUID = "\(UUIDString[0..<8])-\(UUIDString[8..<12])-\(UUIDString[12..<16])-\(UUIDString[16...])"
        guard let id = UUID(uuidString: dashedUUID) else {
            return nil
        }
        self.id = id
    }
}
