@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeDistPersistentStore: SentryScopeDistPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeDistToDiskInvocations = Invocations<String>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeDistToDisk(dist: String) {
        writeDistToDiskInvocations.record(dist)
        super.writeDistToDisk(dist: dist)
    }
} 
