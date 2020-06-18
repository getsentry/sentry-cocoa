import Foundation

extension DebugMeta   {
    open override func isEqual(_ object: Any?) -> Bool {
        if  let other = object as? DebugMeta {
            if uuid != other.uuid {
                return false
            }
            
            if type != other.type {
                return false
            }
            
            if name != other.name {
                return false
            }
            
            if imageSize != other.imageSize {
                return false
            }
            
            if imageAddress != other.imageAddress {
                return false
            }
            
            if imageVmAddress != other.imageVmAddress {
                return false
            }
            
            return true
        } else {
            return false
        }
    }
}
