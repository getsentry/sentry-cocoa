@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeUserPersistentStore: SentryScopeUserPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeContextToDiskInvocations = Invocations<User>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeUserToDisk(user: User) {
        writeContextToDiskInvocations.record(user)
        super.writeUserToDisk(user: user)
    }
}
