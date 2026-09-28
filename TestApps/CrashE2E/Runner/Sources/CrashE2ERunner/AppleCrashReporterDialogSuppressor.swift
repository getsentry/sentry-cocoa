import Foundation

final class AppleCrashReporterDialogSuppressor {
    private let processRunner: ProcessRunner
    private let reportCrashLaunchAgent = "/System/Library/LaunchAgents/com.apple.ReportCrash.plist"

    private var reportCrashWasDisabled = false
    private var isSuppressed = false

    init(processRunner: ProcessRunner) {
        self.processRunner = processRunner
    }

    func suppress() throws {
        guard !isSuppressed else { return }

        try rememberReportCrashDisabledState()

        // Suppress Apple/Problem Reporter UI without disabling the SentryCrash/KSCrash handler
        // installed inside the test app. We intentionally do not touch the root LaunchDaemon because
        // the harness only launches user processes and using sudo from the runner would be inappropriate.
        try processRunner.run(
            "launchctl",
            ["unload", "-w", reportCrashLaunchAgent],
            captureOutput: true,
            allowFailure: true
        )

        isSuppressed = true
    }

    func restore() {
        guard isSuppressed else { return }

        if !reportCrashWasDisabled {
            _ = try? processRunner.run(
                "launchctl",
                ["load", "-w", reportCrashLaunchAgent],
                captureOutput: true,
                allowFailure: true
            )
        }

        isSuppressed = false
    }

    private func rememberReportCrashDisabledState() throws {
        let domain = "gui/\(getuid())"
        let result = try processRunner.run(
            "launchctl",
            ["print-disabled", domain],
            captureOutput: true,
            allowFailure: true
        )
        reportCrashWasDisabled = result.stdout.contains("\"com.apple.ReportCrash\" => disabled")
    }
}
