import Foundation

extension DebugMeta {
     func isEqualTo(other: DebugMeta) -> Bool {
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
    }
}
