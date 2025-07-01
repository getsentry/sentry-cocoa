@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopeFingerprintPersistentStore: SentryScopeFingerprintPersistentStore {
    let moveCurrentFileToPreviousFileInvocations = Invocations<Void>()
    let writeFingerprintToDisk = Invocations<[String]>()

    override func moveCurrentFileToPreviousFile() {
        moveCurrentFileToPreviousFileInvocations.record(())
        super.moveCurrentFileToPreviousFile()
    }

    override func writeFingerprintToDisk(fingerprint: [String]) {
        writeFingerprintToDisk.record(fingerprint)
        super.writeFingerprintToDisk(fingerprint: fingerprint)
    }
} 
