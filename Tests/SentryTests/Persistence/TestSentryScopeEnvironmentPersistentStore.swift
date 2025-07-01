@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeEnvironmentPersistentStore: SentryScopeEnvironmentPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeEnvironmentToDiskInvocations = Invocations<String>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeEnvironmentToDisk(environment: String) {
        writeEnvironmentToDiskInvocations.record(environment)
        super.writeEnvironmentToDisk(environment: environment)
    }
} 
