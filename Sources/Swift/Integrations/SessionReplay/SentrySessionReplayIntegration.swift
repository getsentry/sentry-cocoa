@_implementationOnly import _SentryPrivate
import Foundation

#if canImport(UIKit)
import UIKit

@objcMembers
class SentrySessionReplayIntegration: NSObject, SentryIntegrationProtocol {
    
    private var sessionReplay: SentrySessionReplay?
    
    func install(with options: Options) -> Bool {
        if #available(iOS 16.0, tvOS 16, *) {
            if options.sessionReplayOptions.replaysSessionSampleRate == 0 &&
                options.sessionReplayOptions.replaysOnErrorSampleRate == 0 {
                print("[SessionReplayIntegration] No enabled because sessionReplayOptions is disabled.")
                return false
            }
            
            guard let window = SentryDependencyContainer.sharedInstance().application.windows?.first else {
                print("[SessionReplayIntegration] No window to record")
                return false
            }
            
            sessionReplay = SentrySessionReplay(replayOptions: options.sessionReplayOptions)
            sessionReplay?.start(rootView: window, isFullSession: shouldReplayFullSession(sampleRate: options.sessionReplayOptions.replaysSessionSampleRate))
            
            NotificationCenter.default.addObserver(self, selector: #selector(stop), name: UIApplication.didEnterBackgroundNotification, object: nil)
            
            SentryGlobalEventProcessor.shared().add { event in
                self.sessionReplay?.replayFor(event: event)
                return event
            }
            
        } else {
            print("[SessionReplayIntegration] OS version not supported for session replay. Requires iOS 16 or tvOS 16")
            return false
        }
        return true
    }
    
    func stop() {
       sessionReplay?.stop()
    }
    
    func uninstall() {
        stop()
    }
    
    func shouldReplayFullSession(sampleRate: Float) -> Bool {
        return SentryDependencyContainer.sharedInstance().random.nextNumber() < Double(sampleRate)
    }
}

#endif // canImport(UIKit)
