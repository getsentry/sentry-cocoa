import Foundation

class EmptyIntegration: SentryBaseIntegration {
    override func install(with options: Options) -> Bool {
        return true
    }
}
