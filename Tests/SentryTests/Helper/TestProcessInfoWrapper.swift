import Foundation
import ObjectiveC

class TestProcessInfoWrapper: SentryProcessInfoWrapper {

    override var processDirectoryPath: String {
        guard let imageName = class_getImageName(TestProcessInfoWrapper.self) else {
            return super.processDirectoryPath
        }
        return String(cString: UnsafePointer<CChar>(imageName))
    }
}
