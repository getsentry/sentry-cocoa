import Foundation

#if os(iOS) || os(macOS)

import MetricKit

private let crashMechanism = "MXCrashDiagnostic"
private let diskWriteMechanism = "mx_disk_write_exception"
private let cpuExceptionMechanism = "mx_cpu_exception"
private let hangDiagnosticMechanism = "mx_hang_diagnostic"

@available(macOS 12.0, *)
protocol CallStackTreeProviding {
    var callStackTree: MXCallStackTree { get }
}

@available(macOS 12.0, *)
extension MXCrashDiagnostic: CallStackTreeProviding { }
@available(macOS 12.0, *)
extension MXDiskWriteExceptionDiagnostic: CallStackTreeProviding { }
@available(macOS 12.0, *)
extension MXCPUExceptionDiagnostic: CallStackTreeProviding { }
@available(macOS 12.0, *)
extension MXHangDiagnostic: CallStackTreeProviding { }

@available(macOS 12.0, *)
final class SentryMXManager: NSObject, MXMetricManagerSubscriber {
    
    let disableCrashDiagnostics: Bool
    let measurementFormatter: MeasurementFormatter
    let inAppLogic: SentryInAppLogic
    let attachDiagnosticAsAttachment: Bool
    
    init(inAppLogic: SentryInAppLogic, attachDiagnosticAsAttachment: Bool, disableCrashDiagnostics: Bool = true) {
        self.disableCrashDiagnostics = disableCrashDiagnostics
        self.inAppLogic = inAppLogic
        self.attachDiagnosticAsAttachment = attachDiagnosticAsAttachment
        measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale(identifier: "en_US")
        measurementFormatter.unitOptions = .providedUnit
        super.init()
    }
    
    func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)
    }
    
    func pauseReports() {
        let shared = MXMetricManager.shared
        shared.remove(self)
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        payloads.forEach { payload in
            
            payload.crashDiagnostics?.forEach { diagnostic in
                
                if disableCrashDiagnostics {
                    return
                }
                let exceptionValue = "MachException Type:\(String(describing: diagnostic.exceptionType)) Code:\(String(describing: diagnostic.exceptionCode)) Signal:\(String(describing: diagnostic.signal))"
                captureEvent(handled: false, exceptionValue: exceptionValue, exceptionType: "MXCrashDiagnostic", exceptionMechanism: crashMechanism, timeStampBegin: payload.timeStampBegin, diagnostic: diagnostic)
            }
            
            payload.diskWriteExceptionDiagnostics?.forEach { diagnostic in
                let totalWritesCaused = measurementFormatter.string(from: diagnostic.totalWritesCaused)
                let exceptionValue = "MXDiskWriteException totalWritesCaused:\(totalWritesCaused)"
                captureEvent(handled: true, exceptionValue: exceptionValue, exceptionType: "MXDiskWriteException", exceptionMechanism: diskWriteMechanism, timeStampBegin: payload.timeStampBegin, diagnostic: diagnostic)
            }
            
            payload.cpuExceptionDiagnostics?.forEach { diagnostic in
                let totalCPUTime = measurementFormatter.string(from: diagnostic.totalCPUTime)
                let totalSampledTime = measurementFormatter.string(from: diagnostic.totalSampledTime)

                let exceptionValue = "MXCPUException totalCPUTime:\(totalCPUTime) totalSampledTime:\(totalSampledTime)"
                captureEvent(handled: true, exceptionValue: exceptionValue, exceptionType: "MXCPUException", exceptionMechanism: cpuExceptionMechanism, timeStampBegin: payload.timeStampBegin, diagnostic: diagnostic)
            }
            
            payload.hangDiagnostics?.forEach { diagnostic in
                let hangDuration = measurementFormatter.string(from: diagnostic.hangDuration)
                let exceptionValue = "MXHangDiagnostic hangDuration:\(hangDuration)"
                captureEvent(handled: true, exceptionValue: exceptionValue, exceptionType: "MXHangDiagnostic", exceptionMechanism: hangDiagnosticMechanism, timeStampBegin: payload.timeStampBegin, diagnostic: diagnostic)
            }
        }
    }
    
    func captureEvent(handled: Bool, exceptionValue: String, exceptionType: String, exceptionMechanism: String, timeStampBegin: Date, diagnostic: MXDiagnostic & CallStackTreeProviding) {
        if let callStackTree = try? SentryMXCallStackTree.from(data: diagnostic.callStackTree.jsonRepresentation()) {
            let event = Event(level: handled ? .warning : .error)
            event.timestamp = timeStampBegin
            let exception = Exception(value: exceptionValue, type: exceptionType)
            let mechanism = Mechanism(type: exceptionMechanism)
            mechanism.handled = NSNumber(value: handled)
            mechanism.synthetic = true
            exception.mechanism = mechanism
            event.exceptions = [exception]
            capture(event: event, handled: handled, callStackTree: callStackTree, diagnosticJSON: diagnostic.jsonRepresentation())
        }
    }
    
    func capture(event: Event, handled: Bool, callStackTree: SentryMXCallStackTree, diagnosticJSON: Data) {
        callStackTree.prepare(event: event, inAppLogic: inAppLogic, handled: handled)
        // The crash event can be way from the past. We don't want to impact the current session.
        // Therefore we don't call captureFatalEvent.
        capture(event: event, diagnosticJSON: diagnosticJSON)
    }
    
    func capture(event: Event, diagnosticJSON: Data) {
        if attachDiagnosticAsAttachment {
            SentrySDK.capture(event: event) { scope in
                scope.addAttachment(Attachment(data: diagnosticJSON, filename: "MXDiagnosticPayload.json"))
            }
        } else {
            SentrySDK.capture(event: event)
        }
    }
}

extension Event {
    @objc
    @_spi(Private) public func isMetricKitEvent() -> Bool {
        guard let mechanism = exceptions?.first?.mechanism, exceptions?.count == 1 else {
            return false
        }
        
        return [crashMechanism, diskWriteMechanism, cpuExceptionMechanism, hangDiagnosticMechanism].contains(mechanism.type)
    }
}

#endif
