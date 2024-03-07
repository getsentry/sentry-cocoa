import _SentryPrivate
import Foundation

class RandomWrapper {
    
    func calc() -> Double {
        let random = SentryRandom()
        return random.nextNumber()
    }
}
