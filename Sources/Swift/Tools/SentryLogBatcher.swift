@_implementationOnly import _SentryPrivate
import Foundation

@objc
@objcMembers
@_spi(Private) public class SentryLogBatcher: NSObject {
    
    private let client: SentryClient
    private let flushTimeout: TimeInterval
    private let maxBufferSizeBytes: Int
    private let dispatchQueue: SentryDispatchQueueWrapper
    
    // All mutable state is accessed from the same dispatch queue.
    private var encodedLogs: [Data] = []
    private var encodedLogsSize: Int = 0
    private var timerWorkItem: DispatchWorkItem?

    @_spi(Private) public init(
        client: SentryClient,
        flushTimeout: TimeInterval,
        maxBufferSizeBytes: Int,
        dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.client = client
        self.flushTimeout = flushTimeout
        self.maxBufferSizeBytes = maxBufferSizeBytes
        self.dispatchQueue = dispatchQueue
        super.init()
    }
    
    @_spi(Private) public convenience init(client: SentryClient, dispatchQueue: SentryDispatchQueueWrapper) {
        self.init(
            client: client,
            flushTimeout: 5,
            maxBufferSizeBytes: 1_024 * 1_024, // 1MB
            dispatchQueue: dispatchQueue
        )
    }
    
    func add(_ log: SentryLog) {
        dispatchQueue.dispatchAsync { [weak self] in
            self?.encodeAndBuffer(log: log)
        }
    }
    
    @objc
    public func flush() {
        dispatchQueue.dispatchAsync { [weak self] in
            self?.performFlush()
        }
    }

    // Helper

    // Only ever call this from the dispatch queue.
    private func encodeAndBuffer(log: SentryLog) {
        do {
            let encodedLog = try encodeToJSONData(data: log)
            
            let wasEmpty = encodedLogs.isEmpty
            
            encodedLogs.append(encodedLog)
            encodedLogsSize += encodedLog.count
            
            let shouldFlushImmediatley = encodedLogsSize >= maxBufferSizeBytes
            let shouldStartTimer = wasEmpty && timerWorkItem == nil && !shouldFlushImmediatley
            
            if shouldStartTimer {
                startTimer()
            }
            if shouldFlushImmediatley {
                performFlush()
            }
        } catch {
            SentrySDKLog.error("Failed to encode log: \(error)")
        }
    }
    
    // Only ever call this from the dispatch queue.
    private func startTimer() {
        let timerWorkItem = DispatchWorkItem { [weak self] in
            self?.performFlush()
        }
        self.timerWorkItem = timerWorkItem
        dispatchQueue.queue.asyncAfter(
            deadline: .now() + flushTimeout,
            execute: timerWorkItem
        )
    }

    // Only ever call this from the dispatch queue.
    private func performFlush() {
        let encodedLogsToSend = Array(encodedLogs)

        // Reset buffer state
        encodedLogs.removeAll()
        encodedLogsSize = 0

        // Reset timer state
        timerWorkItem?.cancel()
        timerWorkItem = nil
        
        // If there are no logs to send, return early.
        guard encodedLogsToSend.count > 0 else {
            return
        }

        // Create the payload.
        guard let opening = "{\"items\":[".data(using: .utf8),
            let separator = ",".data(using: .utf8),
            let closing = "]}".data(using: .utf8) else {
            return
        }

        var payloadData = Data()
        payloadData.append(opening)
        for (index, encodedLog) in encodedLogsToSend.enumerated() {
            if index > 0 {
                payloadData.append(separator)
            }
            payloadData.append(encodedLog)
        }
        payloadData.append(closing)
        
        // Send the payload.

        client.captureLogsData(payloadData, with: NSNumber(value: encodedLogsToSend.count))
    }
}
