@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeContextPersistentStore: SentryScopeContextPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeContextToDiskInvocations = Invocations<[String: [String: Any]]>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeContextToDisk(context: [String: [String: Any]]) {
        writeContextToDiskInvocations.record(context)
        super.writeContextToDisk(context: context)
    }
}
