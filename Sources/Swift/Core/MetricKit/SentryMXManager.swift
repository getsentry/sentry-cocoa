import Foundation

#if os(iOS) || os(macOS)

import MetricKit

@available(macOS 12.0, *)
protocol SentryMXManagerDelegate: AnyObject {
    
    func didReceiveCrashDiagnostic(_ diagnostic: MXCrashDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date)
    
    func didReceiveDiskWriteExceptionDiagnostic(_ diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date)
    
    func didReceiveCpuExceptionDiagnostic(_ diagnostic: MXCPUExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date)
    
    func didReceiveHangDiagnostic(_ diagnostic: MXHangDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date)
}

@available(macOS 12.0, *)
final class SentryMXManager: NSObject, MXMetricManagerSubscriber {
    
    let disableCrashDiagnostics: Bool
    
    init(disableCrashDiagnostics: Bool = true) {
        self.disableCrashDiagnostics = disableCrashDiagnostics
        super.init()
    }

    weak var delegate: SentryMXManagerDelegate?
    
    func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)
    }
    
    func pauseReports() {
        let shared = MXMetricManager.shared
        shared.remove(self)
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        func actOn(callStackTree: MXCallStackTree, action: (SentryMXCallStackTree) -> Void) {
            guard let callStackTree = try? SentryMXCallStackTree.from(data: callStackTree.jsonRepresentation()) else {
                return
            }
            
            action(callStackTree)
        }
        
        payloads.forEach { payload in
            
            payload.crashDiagnostics?.forEach { diagnostic in
                
                if disableCrashDiagnostics {
                    return
                }
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveCrashDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin)
                }
            }
            
            payload.diskWriteExceptionDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveDiskWriteExceptionDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin)
                }
            }
            
            payload.cpuExceptionDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveCpuExceptionDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin)
                }
            }
            
            payload.hangDiagnostics?.forEach { diagnostic in
                actOn(callStackTree: diagnostic.callStackTree) { callStackTree in
                    delegate?.didReceiveHangDiagnostic(diagnostic, callStackTree: callStackTree, timeStampBegin: payload.timeStampBegin)
                }
            }
        }
    }
}

#endif
