@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeExtrasPersistentStore: SentryScopeExtrasPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeExtrasToDiskInvocations = Invocations<[String: Any]>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeExtrasToDisk(extras: [String: Any]) {
        writeExtrasToDiskInvocations.record(extras)
        super.writeExtrasToDisk(extras: extras)
    }
} 
