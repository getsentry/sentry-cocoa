@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeLevelPersistentStore: SentryScopeLevelPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeContextToDiskInvocations = Invocations<SentryLevel>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeLevelToDisk(level: SentryLevel) {
        writeContextToDiskInvocations.record(level)
        super.writeLevelToDisk(level: level)
    }
}
