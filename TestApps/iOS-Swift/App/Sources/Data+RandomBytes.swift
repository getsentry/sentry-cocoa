import Foundation

extension Data {
    /// Initialize Data with random bytes of the specified count.
    /// - Parameter randomByteCount: The number of random bytes to generate
    init(randomByteCount: Int) {
        self.init(count: randomByteCount)
        self.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, randomByteCount, baseAddress)
        }
    }
}
