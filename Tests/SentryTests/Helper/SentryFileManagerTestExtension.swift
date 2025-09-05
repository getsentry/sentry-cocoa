import Foundation
import XCTest

extension SentryFileManager {
    
    /**
     * Creates a file at the same path as SentryFileManager stores its files. When init on SentryFileManager is called the init is going to throw an error, because it can't create the internal folders.
     */
    static func prepareInitError() throws {
        try deleteInternalPath()

        let data = Data("hello".utf8)
        let sentryPath = try getSentryCachePath()
        try data.write(to: sentryPath)
    }

    /**
     * Deletes the file created with prepareInitError.
     */
    static func tearDownInitError() throws {
        try deleteInternalPath()
    }
    
    private static func deleteInternalPath() throws {
        let cacheSentryPath = try getSentryCachePath()
        if FileManager.default.fileExists(atPath: cacheSentryPath.path) {
            try FileManager.default.removeItem(at: cacheSentryPath)
        }
    }
    
    private static func getSentryCachePath() throws -> URL {
        let cachePath = try XCTUnwrap(FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first)

        let sentryPath = cachePath.appendingPathComponent("io.sentry")
        return sentryPath
    }

}
