import _SentryPrivate
import Foundation

func wrapRandom() -> Double {
    return SentryRandom().nextNumber()
}
