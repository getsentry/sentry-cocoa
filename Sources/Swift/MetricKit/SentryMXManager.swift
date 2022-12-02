import Foundation

#if os(iOS) || os(macOS)
import MetricKit

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
@objc public protocol SentryMXManagerDelegate: AnyObject {
    
    func didReceiveCrashDiagnostic(_ diagnostic: MXCrashDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)
    
    func didReceiveDiskWriteExceptionDiagnostic(_ diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)
    
    func didReceiveCpuExceptionDiagnostic(_ diagnostic: MXCPUExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date, timeStampEnd: Date)
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
        func actOn(callStackTree: MXCallStackTree, action: (SentryMXCallStackTree) -> Void) {
            guard let callStackTree = try? SentryMXCallStackTree.from(data: callStackTree.jsonRepresentation()) else {
                return
            }
            
            action(callStackTree)
        }
        
        payloads.forEach { payload in
            payload.crashDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveCrashDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
            
            payload.diskWriteExceptionDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveDiskWriteExceptionDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
            
            payload.cpuExceptionDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveCpuExceptionDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin, timeStampEnd: payload.timeStampEnd)
                }
            }
        }
    }
}

#endif
