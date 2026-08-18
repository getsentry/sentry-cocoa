import Darwin
import Foundation
import UIKit

OS27PrewarmProbe.shared.recordMain()
let exitCode = UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)
exit(exitCode)
