import Foundation

protocol SentrySDKCrashDetection {
    func sdkCrashDetected()
}

@objc
class SentryFailSafe: NSObject {

    private let userDefaults = UserDefaults.standard
    private let userDefaultsKey = "sentry_fail_safe_sdk_start_status"
    private let startedSuffix = "_started"
    private let successSuffix = "_success"
    private let sdkCrashDetection: SentrySDKCrashDetection

    init(sdkCrashDetection: SentrySDKCrashDetection) {
        self.sdkCrashDetection = sdkCrashDetection
    }

    @objc
    func sdkStartStarted(releaseName: String) {
        if previousSDKStartStatus(releaseName: releaseName) == .failure {
            sdkCrashDetection.sdkCrashDetected()
        }

        reset()
        userDefaults.set(releaseName + startedSuffix, forKey: userDefaultsKey)
    }

    @objc func sdkStartFinished(releaseName: String) {
        userDefaults.set(releaseName + successSuffix, forKey: userDefaultsKey)
    }

    private func previousSDKStartStatus(releaseName: String) -> StartStatus {

        guard let storedReleaseName = userDefaults.string(forKey: userDefaultsKey) else {
            return .unknown
        }

        if storedReleaseName == releaseName + successSuffix {
            return .success
        } else {
            return .failure
        }
    }

    @objc func reset() {
        userDefaults.removeObject(forKey: userDefaultsKey)
    }

    private enum StartStatus {
        case unknown
        case success
        case failure
    }

}
