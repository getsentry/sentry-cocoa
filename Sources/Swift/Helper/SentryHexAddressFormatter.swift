import Foundation

func sentry_formatHexAddress(_ value: UInt64) -> String {
    String(format: "0x%016llx", value)
}
