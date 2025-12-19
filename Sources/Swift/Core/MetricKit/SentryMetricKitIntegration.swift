#if os(iOS) || os(macOS)
import MetricKit

@available(macOS 12.0, *)
final class SentryMetricKitIntegration<Dependencies>: NSObject, SwiftIntegration {
    
    let mxManager: SentryMXManager
    let measurementFormatter: MeasurementFormatter
    let attachDiagnosticAsAttachment: Bool
    let inAppLogic: SentryInAppLogic
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableMetricKit else {
            return nil
        }

        mxManager = SentryMXManager()
        measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale(identifier: "en_US")
        measurementFormatter.unitOptions = .providedUnit
        attachDiagnosticAsAttachment = options.enableMetricKitRawPayload
        inAppLogic = SentryInAppLogic(inAppIncludes: options.inAppIncludes)
        super.init()
        
        mxManager.delegate = self
        mxManager.receiveReports()
    }
    
    static var name: String {
        "SentryMetricKitIntegration"
    }
    
    func uninstall() {
        mxManager.pauseReports()
        mxManager.delegate = nil
    }
    
    static func createEvent(handled: Bool, level: SentryLevel, exceptionValue: String, exceptionType: String, exceptionMechanism: String, timeStampBegin: Date) -> Event {
        let event = Event(level: level)
        event.timestamp = timeStampBegin
        let exception = Exception(value: exceptionValue, type: exceptionType)
        let mechanism = Mechanism(type: exceptionMechanism)
        mechanism.handled = NSNumber(value: handled)
        mechanism.synthetic = true
        exception.mechanism = mechanism
        event.exceptions = [exception]
        return event
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

private let crashMechanism = "MXCrashDiagnostic"
private let diskWriteMechanism = "mx_disk_write_exception"
private let cpuExceptionMechanism = "mx_cpu_exception"
private let hangDiagnosticMechanism = "mx_hang_diagnostic"

@available(macOS 12.0, *)
extension SentryMetricKitIntegration: SentryMXManagerDelegate {
    func didReceiveCrashDiagnostic(_ diagnostic: MXCrashDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date) {
        let exceptionValue = "MachException Type:\(String(describing: diagnostic.exceptionType)) Code:\(String(describing: diagnostic.exceptionCode)) Signal:\(String(describing: diagnostic.signal))"
        let event = Self.createEvent(handled: false, level: .error, exceptionValue: exceptionValue, exceptionType: "MXCrashDiagnostic", exceptionMechanism: crashMechanism, timeStampBegin: timeStampBegin)
        capture(event: event, handled: false, callStackTree: callStackTree, diagnosticJSON: diagnostic.jsonRepresentation())
    }
    
    func didReceiveDiskWriteExceptionDiagnostic(_ diagnostic: MXDiskWriteExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date) {
        let totalWritesCaused = measurementFormatter.string(from: diagnostic.totalWritesCaused)
        let exceptionValue = "MXDiskWriteException totalWritesCaused:\(totalWritesCaused)"
        let event = Self.createEvent(handled: true, level: .warning, exceptionValue: exceptionValue, exceptionType: "MXDiskWriteException", exceptionMechanism: diskWriteMechanism, timeStampBegin: timeStampBegin)
        capture(event: event, handled: true, callStackTree: callStackTree, diagnosticJSON: diagnostic.jsonRepresentation())
    }
    
    func didReceiveCpuExceptionDiagnostic(_ diagnostic: MXCPUExceptionDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date) {
        let totalCPUTime = measurementFormatter.string(from: diagnostic.totalCPUTime)
        let totalSampledTime = measurementFormatter.string(from: diagnostic.totalSampledTime)

        let exceptionValue = "MXCPUException totalCPUTime:\(totalCPUTime) totalSampledTime:\(totalSampledTime)"
        let event = Self.createEvent(handled: true, level: .warning, exceptionValue: exceptionValue, exceptionType: "MXCPUException", exceptionMechanism: cpuExceptionMechanism, timeStampBegin: timeStampBegin)
        capture(event: event, handled: true, callStackTree: callStackTree, diagnosticJSON: diagnostic.jsonRepresentation())
    }
    
    func didReceiveHangDiagnostic(_ diagnostic: MXHangDiagnostic, callStackTree: SentryMXCallStackTree, timeStampBegin: Date) {
        let hangDuration = measurementFormatter.string(from: diagnostic.hangDuration)
        let exceptionValue = "MXHangDiagnostic hangDuration:\(hangDuration)"
        let event = Self.createEvent(handled: true, level: .warning, exceptionValue: exceptionValue, exceptionType: "MXHangDiagnostic", exceptionMechanism: hangDiagnosticMechanism, timeStampBegin: timeStampBegin)
        capture(event: event, handled: true, callStackTree: callStackTree, diagnosticJSON: diagnostic.jsonRepresentation())
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
