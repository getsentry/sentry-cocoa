@_implementationOnly import _SentryPrivate
import Foundation

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    
    private let client: SentryClient
    private let flushTimeout: TimeInterval
    private let maxBufferSize: Int
    private let dispatchQueue: SentryDispatchQueueWrapper
    
    private var logBuffer: [SentryLog] = []
    private let logBufferLock = NSLock()
    private var currentFlushId: UUID?
    
    @_spi(Private) public init(
        client: SentryClient,
        flushTimeout: TimeInterval,
        maxBufferSize: Int,
        dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.client = client
        self.flushTimeout = flushTimeout
        self.maxBufferSize = maxBufferSize
        self.dispatchQueue = dispatchQueue
        super.init()
    }
    
    @_spi(Private) public convenience init(client: SentryClient, dispatchQueue: SentryDispatchQueueWrapper) {
        self.init(
            client: client,
            flushTimeout: 5,
            maxBufferSize: 100,
            dispatchQueue: dispatchQueue
        )
    }
    
    func add(_ log: SentryLog) {
        cancelFlush()

        let shouldFlush = logBufferLock.synchronized {
            logBuffer.append(log)
            return logBuffer.count >= maxBufferSize
        }
        
        if !shouldFlush {
            scheduleFlush()
        } else {
            flush()
        }
    }
    
    @objc
    public func flush() {
        cancelFlush()

        let logs = logBufferLock.synchronized {
            let logs = Array(logBuffer)
            logBuffer.removeAll()
            return logs
        }
        
        if !logs.isEmpty {
            dispatch(logs: logs)
        }
    }

    private func scheduleFlush() {
        let flushId = UUID()
        
        logBufferLock.synchronized {
            currentFlushId = flushId
        }
        
        dispatchQueue.dispatch(after: flushTimeout) { [weak self] in
            self?.executeFlushIfMatching(flushId: flushId)
        }
    }

    private func executeFlushIfMatching(flushId: UUID) {
        let shouldFlush = logBufferLock.synchronized {
            return currentFlushId == flushId
        }
        
        if shouldFlush {
            flush()
        }
    }

    private func cancelFlush() {
        logBufferLock.synchronized {
            currentFlushId = nil
        }
    }
    
    private func dispatch(logs: [SentryLog]) {
        do {
            let payload = ["items": logs]
            let data = try encodeToJSONData(data: payload)
            
            client.captureLogsData(data)
        } catch {
            SentrySDKLog.error("Failed to create logs envelope.")
        }
    }
}
