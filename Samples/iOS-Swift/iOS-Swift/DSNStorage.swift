import Foundation
import Sentry

/**
 * Stores the DSN to a file in the cache directory.
 */
class DSNStorage {
    
    static let shared = DSNStorage()
    
    private let dsnFile: URL
    
    private init() {
        // swiftlint:disable force_unwrapping
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        // swiftlint:enable force_unwrapping
        dsnFile = cachesDirectory.appendingPathComponent("dsn")
    }
    
    func saveDSN(dsn: String) {
        do {
            deleteDSN()
            try dsn.write(to: dsnFile, atomically: true, encoding: .utf8)
        } catch {
            SentrySDK.capture(error: error)
        }
    }
    
    func getDSN() -> String? {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: dsnFile.path) {
                return try String(contentsOfFile: dsnFile.path)
            }
        } catch {
            SentrySDK.capture(error: error)
        }
        
        return nil
    }
    
    func deleteDSN() {
        let fileManager = FileManager.default
        do {
            
            if fileManager.fileExists(atPath: dsnFile.path) {
                try fileManager.removeItem(at: dsnFile)
            }
        } catch {
            SentrySDK.capture(error: error)
        }
    }
}
