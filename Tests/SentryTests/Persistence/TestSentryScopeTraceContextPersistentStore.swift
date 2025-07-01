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

    override func deleteStateOnDisk() {
        deleteTraceContextOnDiskInvocations += 1
        super.deleteStateOnDisk()
    }

    override func deletePreviousStateOnDisk() {
        deletePreviousTraceContextOnDiskInvocations += 1
        super.deletePreviousStateOnDisk()
    }
} 
