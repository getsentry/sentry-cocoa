import Intents
import Sentry
@_spi(Private) @testable import Sentry
import SentrySampleShared

class IntentHandler: INExtension, INSendMessageIntentHandling {

    override init() {
        super.init()
        setupSentry()
    }

    override func handler(for intent: INIntent) -> Any {
        setupSentry()
        return self
    }

    private func setupSentry() {
        // Prevent double initialization - SentrySDK.start() can be called multiple times
        // but we want to avoid unnecessary re-initialization
        guard !SentrySDK.isEnabled else {
            return
        }
        
        // For this extension we need a specific configuration set, therefore we do not use the shared sample initializer
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true

            // App Hang Tracking must be enabled, but should not be installed
            options.enableAppHangTracking = true
        }
    }
    
    // MARK: - INSendMessageIntentHandling
    
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        let person = INPerson(
            personHandle: INPersonHandle(value: "john-snow", type: .unknown),
            nameComponents: PersonNameComponents(givenName: "John", familyName: "Snow"),
            displayName: "John Snow",
            image: nil,
            contactIdentifier: nil,
            customIdentifier: nil
        )
        completion([INSendMessageRecipientResolutionResult.success(with: person)])
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        let message = """
        Sentry Enabled? \(isSentryEnabled ? "✅" : "❌")
        ANR Disabled? \(!isANRInstalled ? "✅" : "❌")
        """
        completion(INStringResolutionResult.success(with: message))
    }
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        completion(INSendMessageIntentResponse(code: .ready, userActivity: userActivity))
    }
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        SentrySDK.capture(message: "iOS-Swift-IntentExtension: handle intent called")

        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        completion(INSendMessageIntentResponse(code: .success, userActivity: userActivity))
    }

    // MARK: - Helpers

    var isANRInstalled: Bool {
        return isSentryEnabled && SentrySDKInternal.trimmedInstalledIntegrationNames().contains("ANRTracking")
    }

    var isSentryEnabled: Bool {
        SentrySDK.isEnabled
    }
}
