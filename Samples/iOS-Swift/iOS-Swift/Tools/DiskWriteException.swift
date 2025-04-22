import Foundation
import Sentry

/**
 * The system throws an exception and generates a report when the disk writes from your app exceed a certain threshold in a 24-hour period.
 * See https://developer.apple.com/documentation/xcode/reducing-disk-write.
 * Therefore we write plenty of data to disk on a background thread to hopefully trigger a DiskWriteException.
 */
class DiskWriteException {
    
    private let dispatchQueue = DispatchQueue(label: "DiskWriteException", attributes: [.concurrent])
    private let folder: URL
    private var running = false
    
    init() {
        // swiftlint:disable force_unwrapping
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        // swiftlint:enable force_unwrapping
        folder = cachesDirectory.appendingPathComponent("DiskWriteException/")
    }
    
    func continuouslyWriteToDisk() {
        if running {
            return
        }
        
        running = true
        
        dispatchQueue.async {
            do {
                let fileManager = FileManager.default
                try fileManager.createDirectory(at: self.folder, withIntermediateDirectories: true)
                
                let url = self.folder.appendingPathComponent("SomeBytes.txt")
                fileManager.createFile(atPath: url.absoluteString, contents: nil)
                
                // Keep writing random data to SomeBytes.txt
                while true {
                    var data = Data()
                    for _ in 0..<100_000 {
                        let random = UInt8.random(in: 0...10)
                        data.append(Data(repeating: random, count: 50))
                    }
                    
                    try data.write(to: url, options: .atomic)
                    self.delay()
                }
            } catch {
                SentrySDK.capture(error: error)
            }
        }
    }
    
    private func delay(timeout: Double = 0.1) {
        let group = DispatchGroup()
        group.enter()
        
        self.dispatchQueue.asyncAfter(deadline: .now() + timeout) {
            group.leave()
        }
        
        group.wait()
    }
    
    func deleteFiles() {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: folder.path) {
                try fileManager.removeItem(at: folder)
            }
        } catch {
            SentrySDK.capture(error: error)
        }
    }
}
