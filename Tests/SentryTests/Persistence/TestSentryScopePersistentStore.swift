@_spi(Private) @testable import Sentry
import SentryTestUtils

class TestSentryScopePersistentStore: SentryScopePersistentStore {
    let moveAllCurrentStateToPreviousStateInvocations = Invocations<Void>()
    let writeContextToDiskInvocations = Invocations<[String: [String: Any]]>()
    let writeUserToDiskInvocations = Invocations<User>()

    override func moveAllCurrentStateToPreviousState() {
        moveAllCurrentStateToPreviousStateInvocations.record(())
        super.moveAllCurrentStateToPreviousState()
    }
    
    override func writeContextToDisk(context: [String: [String: Any]]) {
        writeContextToDiskInvocations.record(context)
        super.writeContextToDisk(context: context)
    }
    
    override func writeUserToDisk(user: User) {
        writeUserToDiskInvocations.record(user)
        super.writeUserToDisk(user: user)
    }
}
