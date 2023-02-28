import Foundation

extension DebugMeta {
    open override func isEqual(_ object: Any?) -> Bool {
        if  let other = object as? DebugMeta {
            return  uuid == other.uuid &&
            debugID == other.debugID &&
                type == other.type &&
                name == other.name &&
                codeFile == other.codeFile &&
                imageSize == other.imageSize &&
                imageAddress == other.imageAddress &&
                imageVmAddress == other.imageVmAddress
        } else {
            return false
        }
    }
    
    override open var description: String {
        "\(self.serialize())"
    }
}
