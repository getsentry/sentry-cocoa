import Foundation

enum IOSAppState: CustomStringConvertible {
    case unknown
    case stopped(lastPID: Int32?)
    case observed(ProcessExitObserver)

    var observer: ProcessExitObserver? {
        guard case .observed(let observer) = self else { return nil }
        return observer
    }

    var description: String {
        switch self {
        case .unknown:
            return "unknown (no confirmed launch PID)"
        case .stopped(let pid):
            return pid.map { "known stopped (last PID \($0))" } ?? "known stopped (simulator confirmed)"
        case .observed(let observer):
            return "observing PID \(observer.processIdentifier) (exit not yet confirmed)"
        }
    }
}

enum IOSRunnerPhase: String {
    case setup
    case installation
    case scenarioSetup = "scenario setup"
    case launch
    case waitingForExit = "waiting for app exit"
    case readiness = "waiting for app readiness"
    case signalDelivery = "signal delivery"
    case reportValidation = "report validation"
    case cleanup
    case diagnostics
}

struct SimulatorCommandFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        "Simulator infrastructure failure (scenario incomplete): \(message)"
    }
}
