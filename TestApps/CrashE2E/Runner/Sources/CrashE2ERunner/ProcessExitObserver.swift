import Darwin
import Foundation

/// Observes a non-child process (simulator apps are children of launchd, not this runner).
/// Unlike launchctl's loaded-job list or kill(pid, 0), NOTE_EXIT also handles zombies.
/// After registration, observation stays tied to that process even if its PID is reused.
/// simctl supplies only a PID: reuse between launch and registration cannot be detected here.
/// An observed exit proves termination, not successful crash reporting or delivery.
final class ProcessExitObserver {
    let processIdentifier: Int32
    private let descriptor: Int32
    private var exited = false

    init(processIdentifier: Int32) throws {
        guard processIdentifier > 0 else {
            try fail("Invalid process identifier: \(processIdentifier)")
        }

        self.processIdentifier = processIdentifier

        let descriptor = kqueue()
        guard descriptor >= 0 else {
            try fail("Could not create process exit observer: \(String(cString: strerror(errno)))")
        }

        do {
            guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) != -1 else {
                try fail("Could not configure process exit observer: \(String(cString: strerror(errno)))")
            }

            var change = kevent64_s(
                ident: UInt64(processIdentifier), filter: Int16(EVFILT_PROC),
                flags: UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT), fflags: NOTE_EXIT,
                data: 0, udata: 0, ext: (0, 0)
            )
            while kevent64(descriptor, &change, 1, nil, 0, 0, nil) == -1 {
                let code = errno
                if code == EINTR { continue }

                // Fast crash scenarios can exit before simctl launch returns. ESRCH is the
                // only registration error that means termination.
                guard code == ESRCH else {
                    try fail("Could not observe PID \(processIdentifier): \(String(cString: strerror(code)))")
                }

                exited = true
                break
            }
        } catch {
            close(descriptor)
            throw error
        }
        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
    }

    func wait(timeout: TimeInterval) throws -> Bool {
        if exited { return true }

        let deadline = DispatchTime.now() + max(0, timeout)

        repeat {
            let now = DispatchTime.now().uptimeNanoseconds
            let remaining = deadline.uptimeNanoseconds > now ? deadline.uptimeNanoseconds - now : 0
            var duration = timespec(tv_sec: Int(remaining / 1_000_000_000), tv_nsec: Int(remaining % 1_000_000_000))
            var event = kevent64_s()

            let count = kevent64(descriptor, nil, 0, &event, 1, 0, &duration)
            if count == -1 {
                let code = errno
                if code == EINTR { continue }

                try fail("Could not wait for PID \(processIdentifier): \(String(cString: strerror(code)))")
            }

            if count == 0 { return false }

            guard event.flags & UInt16(EV_ERROR) == 0, event.fflags & NOTE_EXIT != 0 else {
                try fail("Unexpected process exit event for PID \(processIdentifier): \(event)")
            }

            exited = true
            return true
        } while DispatchTime.now() < deadline

        return false
    }

    /// `simctl launch` prints `<bundle id>: <pid>`. Reject unrelated output, nonpositive
    /// PIDs and ambiguous responses rather than silently treating a parse error as an exit.
    static func launchedProcessIdentifier(stdout: String, bundleID: String) throws -> Int32 {
        let prefix = "\(bundleID):"
        let lines = stdout.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix(prefix) }

        guard lines.count == 1,
              let line = lines.first,
              let pid = Int32(line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)),
              pid > 0 else {
            try fail("Could not parse the launched iOS PID for \(bundleID) from simctl output: \(stdout)")
        }

        return pid
    }
}
