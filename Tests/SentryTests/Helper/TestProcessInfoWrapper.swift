import Foundation
import ObjectiveC

class TestProcessInfoWrapper: SentryProcessInfoWrapper {

    override var processDirectoryPath: String {
        return "sentrytest"
    }
}
