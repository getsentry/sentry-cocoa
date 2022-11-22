import Foundation
import MetricKit

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
@objc public protocol SentryMXManagerDelegate: AnyObject {
    func didReceiveCrashDiagnostic(_ crashDiagnostic: MXCrashDiagnostic, callStackTree: SentryMXCallStackTree)
}

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
@objc public class SentryMXManager: NSObject, MXMetricManagerSubscriber {

    @objc public weak var delegate: SentryMXManagerDelegate?
    
    @objc public func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)
    }
    
    @objc public func pauseReports() {
        let shared = MXMetricManager.shared
        shared.remove(self)
    }
    
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        payloads.forEach { payload in
            payload.crashDiagnostics?.forEach {
                let json = $0.callStackTree.jsonRepresentation()
                let callStackTree = try! SentryMXCallStackTree.from(data: json)
                
                delegate?.didReceiveCrashDiagnostic($0, callStackTree: callStackTree)
            }
            
            payload.diskWriteExceptionDiagnostics?.forEach {
                let json = $0.callStackTree.jsonRepresentation()
                _ = try! SentryMXCallStackTree.from(data: json)
            }
            
            payload.hangDiagnostics?.forEach {
                let json = $0.callStackTree.jsonRepresentation()
                _ = try! SentryMXCallStackTree.from(data: json)
            }
            
            payload.cpuExceptionDiagnostics?.forEach {
                let json = $0.callStackTree.jsonRepresentation()
                _ = try! SentryMXCallStackTree.from(data: json)
            }
        }
    }
}
