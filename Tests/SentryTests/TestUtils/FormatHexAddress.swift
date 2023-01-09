import Foundation

func formatHexAddress(value: UInt64) -> String {
    return String(format: "0x%016llx", value)
}
