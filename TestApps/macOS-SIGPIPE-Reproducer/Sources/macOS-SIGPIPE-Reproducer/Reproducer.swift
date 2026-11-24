import Darwin
import Foundation
import SentrySwift

// Reproduces https://github.com/getsentry/sentry-cocoa/issues/1589.
//
// On Darwin, a write to a closed pipe or socket raises SIGPIPE for the whole process, and the
// kernel delivers it to the first non-workqueue thread that does not block it. This tool starts
// the SDK, blocks SIGPIPE on the main thread so the kernel cannot pick it, writes to a closed
// pipe, and prints which thread received the signal.

/// State that the signal handler reads. It is allocated before the handler is installed, so the
/// handler only reads memory and calls async-signal-safe functions.
private enum HandlerState {
    static let nameCapacity = 64
    static let receiverName = UnsafeMutablePointer<CChar>.allocate(capacity: nameCapacity)
    static let sdkThreadCapacity = 256
    static let sdkThreads = UnsafeMutablePointer<thread_act_t>.allocate(capacity: sdkThreadCapacity)
    static var sdkThreadCount = 0
}

private struct ThreadInfo {
    let port: thread_act_t
    let name: String
}

private func writeToStandardError(_ message: StaticString) {
    message.withUTF8Buffer { buffer in
        _ = write(STDERR_FILENO, buffer.baseAddress, buffer.count)
    }
}

private func reportReceivingThread(_ signal: Int32) {
    let name = HandlerState.receiverName
    pthread_getname_np(pthread_self(), name, HandlerState.nameCapacity)
    let receiver = pthread_mach_thread_np(pthread_self())
    var startedBySDK = false
    for index in 0..<HandlerState.sdkThreadCount where HandlerState.sdkThreads[index] == receiver {
        startedBySDK = true
    }

    writeToStandardError("SIGPIPE delivered to thread: ")
    if name.pointee == 0 {
        writeToStandardError("<unnamed>")
    } else {
        _ = write(STDERR_FILENO, name, strlen(name))
    }
    if startedBySDK {
        writeToStandardError(" (started by SentrySDK.start)\nRESULT: an SDK thread received the signal.\n")
        _exit(1)
    }
    writeToStandardError(" (existed before SentrySDK.start)\nRESULT: an app thread received the signal.\n")
    _exit(0)
}

private func currentThreads() -> [ThreadInfo] {
    var list: thread_act_array_t?
    var count: mach_msg_type_number_t = 0
    guard task_threads(mach_task_self_, &list, &count) == KERN_SUCCESS, let list else {
        return []
    }
    defer {
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: list)), vm_size_t(Int(count) * MemoryLayout<thread_act_t>.stride))
    }
    return (0..<Int(count)).map { index in
        var name = [CChar](repeating: 0, count: HandlerState.nameCapacity)
        if let thread = pthread_from_mach_thread_np(list[index]) {
            pthread_getname_np(thread, &name, HandlerState.nameCapacity)
        }
        return ThreadInfo(port: list[index], name: String(cString: name))
    }
}

@main
enum Reproducer {
    static func main() {
        HandlerState.receiverName.initialize(repeating: 0, count: HandlerState.nameCapacity)
        let threadsBeforeStart = Set(currentThreads().map(\.port))

        SentrySDK.start { options in
            options.dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? "https://public@o0.ingest.sentry.io/0"
            options.debug = ProcessInfo.processInfo.environment["SENTRY_DEBUG"] == "1"
            // App hang tracking runs its own thread, which could also receive the signal.
            options.enableAppHangTracking = false
            options.enableAutoSessionTracking = false
        }
        // Let the SDK threads start and set up their signal masks.
        Thread.sleep(forTimeInterval: 1)

        let sdkThreads = currentThreads().filter { !threadsBeforeStart.contains($0.port) }
        for (index, thread) in sdkThreads.prefix(HandlerState.sdkThreadCapacity).enumerated() {
            HandlerState.sdkThreads[index] = thread.port
        }
        HandlerState.sdkThreadCount = min(sdkThreads.count, HandlerState.sdkThreadCapacity)
        print("Threads created by SentrySDK.start (unnamed ones include GCD worker threads):")
        for thread in sdkThreads {
            print("  - \(thread.name.isEmpty ? "<unnamed>" : thread.name)")
        }

        // This replaces the SDK's SIGPIPE handler. The kernel picks the receiving thread from the
        // threads' signal masks, not from the handler, so the handler only reports that choice.
        var action = sigaction()
        action.__sigaction_u.__sa_handler = reportReceivingThread
        sigemptyset(&action.sa_mask)
        guard sigaction(SIGPIPE, &action, nil) == 0 else {
            fatalError("Installing the SIGPIPE handler failed.")
        }

        // Block SIGPIPE on the main thread so the kernel has to deliver it to another thread.
        var signals = sigset_t()
        sigemptyset(&signals)
        sigaddset(&signals, SIGPIPE)
        pthread_sigmask(SIG_BLOCK, &signals, nil)

        var pipeDescriptors: [Int32] = [0, 0]
        guard pipe(&pipeDescriptors) == 0 else {
            fatalError("Creating the pipe failed.")
        }
        close(pipeDescriptors[0])
        var byte: UInt8 = 0
        let written = write(pipeDescriptors[1], &byte, 1)
        let writeError = errno
        print("Writing to the closed pipe returned \(written): \(String(cString: strerror(writeError)))")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 1)

        // The secondary exception handler thread suspends itself when it starts. A signal that the
        // kernel assigns to it stays pending until the thread resumes, so resume it to reveal that.
        if let secondary = currentThreads().first(where: { $0.name == "SentryCrash Exception Handler (Secondary)" }) {
            print("No thread ran the handler within 1 second. Resuming the secondary exception handler thread.")
            fflush(stdout)
            thread_resume(secondary.port)
            Thread.sleep(forTimeInterval: 1)
        }

        print("RESULT: no thread received the signal. Every thread that could receive it blocks it, so it stays pending.")
        exit(0)
    }
}
