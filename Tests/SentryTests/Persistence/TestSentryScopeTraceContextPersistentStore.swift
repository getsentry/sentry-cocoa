import Foundation
@_spi(Private) @testable import Sentry

class TestSentryScopeTraceContextPersistentStore: SentryScopeTraceContextPersistentStore {
    var writeTraceContextToDiskInvocations = [[String: Any]]()
    var deleteTraceContextOnDiskInvocations = 0
    var deletePreviousTraceContextOnDiskInvocations = 0

    override func writeTraceContextToDisk(traceContext: [String: Any]) {
        writeTraceContextToDiskInvocations.append(traceContext)
        super.writeTraceContextToDisk(traceContext: traceContext)
    }

    override func deleteTraceContextOnDisk() {
        deleteTraceContextOnDiskInvocations += 1
        super.deleteTraceContextOnDisk()
    }

    override func deletePreviousTraceContextOnDisk() {
        deletePreviousTraceContextOnDiskInvocations += 1
        super.deletePreviousTraceContextOnDisk()
    }
} 
