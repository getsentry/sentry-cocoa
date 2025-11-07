import Intents
import Sentry
@_spi(Private) @testable import Sentry
import SentrySampleShared

class IntentHandler: INExtension, INSendMessageIntentHandling {
    
    private static var hasSetupSentry = false
    
    override init() {
        super.init()
        print("🔵 IntentHandler.init() called")
        setupSentrySDK()
    }
    
    private func setupSentrySDK() {
        // Only setup once per process
        guard !Self.hasSetupSentry else {
            return
        }
        Self.hasSetupSentry = true
        
        print("🔵 IntentHandler.setupSentrySDK() called")
        SentrySDKWrapper.shared.startSentry()
        
        // Small delay to ensure SDK is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkANRStatus()
        }
    }
    
    private func checkANRStatus() {
        // Verify ANR tracking is disabled
        var anrInstalled = false
        if SentrySDK.isEnabled {
            let integrationNames = SentrySDKInternal.trimmedInstalledIntegrationNames()
            anrInstalled = integrationNames.contains("ANRTracking")
        }
        
        if anrInstalled {
            print("❌ ERROR: ANR tracking should be disabled in Intent Extension but it's enabled!")
        } else {
            print("✅ ANR tracking is correctly disabled in Intent Extension")
        }
    }
    
    override func handler(for intent: INIntent) -> Any {
        print("🔵 IntentHandler.handler(for intent:) called with intent: \(type(of: intent))")
        // Ensure Sentry is setup when handler is requested
        setupSentrySDK()
        return self
    }
    
    // MARK: - INSendMessageIntentHandling
    
    // Implement resolution methods to provide additional information about your intent (optional).
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        if let recipients = intent.recipients {
            // If no recipients were provided we'll need to prompt for a value.
            if recipients.count == 0 {
                completion([INSendMessageRecipientResolutionResult.needsValue()])
                return
            }
            
            var resolutionResults = [INSendMessageRecipientResolutionResult]()
            for recipient in recipients {
                let matchingContacts = [recipient] // Implement your contact matching logic here to create an array of matching contacts
                switch matchingContacts.count {
                case 2 ... Int.max:
                    // We need Siri's help to ask user to pick one from the matches.
                    resolutionResults += [INSendMessageRecipientResolutionResult.disambiguation(with: matchingContacts)]
                    
                case 1:
                    // We have exactly one matching contact
                    resolutionResults += [INSendMessageRecipientResolutionResult.success(with: recipient)]
                    
                case 0:
                    // We have no contacts matching the description provided
                    resolutionResults += [INSendMessageRecipientResolutionResult.unsupported()]
                    
                default:
                    break
                }
            }
            completion(resolutionResults)
        } else {
            completion([INSendMessageRecipientResolutionResult.needsValue()])
        }
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty {
            completion(INStringResolutionResult.success(with: text))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    // Once resolution is completed, perform validation on the intent and provide confirmation (optional).
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Verify user is authenticated and your app is ready to send a message.
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
        completion(response)
    }
    
    // Handle the completed intent (required).
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        print("🔵 IntentHandler.handle(intent:) called")
        SentrySDK.capture(message: "iOS-Swift-IntentExtension: handle intent called")
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(code: .success, userActivity: userActivity)
        completion(response)
    }
}
