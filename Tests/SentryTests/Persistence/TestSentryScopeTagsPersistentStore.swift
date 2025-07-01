@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeTagsPersistentStore: SentryScopeTagsPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeContextToDiskInvocations = Invocations<[String: String]>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeTagsToDisk(tags: [String: String]) {
        writeContextToDiskInvocations.record(tags)
        super.writeTagsToDisk(tags: tags)
    }
}
