// TODO: remove this
// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation
import KSCrashRecording

// TODO: go through all previous comments and see which are still relevant

// MARK: - Report Helpers
// These extensions are all to make the Report Converter code a little more idiomatic and nice to read
extension CrashField {
    static let sentrySDKScope = CrashField(rawValue: "sentry_sdk_scope")
    static let attachments = CrashField(rawValue: "attachments")
}

private extension [String: Any] {
    subscript<T>(_ field: CrashField, _ type: T.Type = T.self) -> T? {
        self[field.rawValue] as? T
    }

    func uintValue(_ field: CrashField) -> UInt {
        UInt((self[field.rawValue] as? NSNumber)?.uint64Value ?? 0)
    }
}

private extension CrashReportDictionary {
    subscript<T>(_ field: CrashField, _ type: T.Type = T.self) -> T? {
        value[field.rawValue] as? T
    }
}

private extension ExceptionType {
    static let unknown = ExceptionType(rawValue: "Unknown Exception")
}

// MARK: - Report Converter
@objc @_spi(Private)
public final class KSCrashReportConverter: NSObject {
    private let report: CrashReportDictionary
    private let userContext: [String: Any]
    private let exceptionContext: [String: Any]?
    private let binaryImages: [[String: Any]]
    private let threads: [[String: Any]]
    private let crashedThreadIndex: Int
    private let systemContext: [String: Any]
    private let applicationStats: [String: Any]?
    private let diagnosis: String?
    private let inAppLogic: SentryInAppLogic

    @objc
    public init(report: CrashReportDictionary, inAppLogic: SentryInAppLogic) {
        self.report = report
        self.inAppLogic = inAppLogic

        // KSCrash writes scope as report["user"]["sentry_sdk_scope"]. Flatten it into
        // userContext so downstream code can access scope fields directly.
        var userSection: [String: Any] = report[.user] ?? [:]
        if let scope: [String: Any] = userSection[.sentrySDKScope] {
            userSection.merge(scope) { _, new in new }
        }
        userSection.removeValue(forKey: CrashField.sentrySDKScope.rawValue)
        self.userContext = userSection

        // Prefer recrash_report data when present.
        let preferredReport: [String: Any] = report[.recrashReport] ?? report.value

        self.binaryImages = preferredReport[.binaryImages] ?? []

        let crashContext: [String: Any]? = preferredReport[.crash]

        self.diagnosis = crashContext?[.diagnosis]
        self.exceptionContext = crashContext?[.error]

        let systemContext: [String: Any] = report[.system] ?? [:]
        self.systemContext = systemContext
        self.applicationStats = systemContext[.appStats]

        // KSCrash recrash_reports may contain NSString elements in the threads array
        // instead of NSDictionary. Filter those out to avoid crashes during iteration.
        let rawThreads: [Any] = crashContext?[.threads] ?? []
        let threads = rawThreads.compactMap { $0 as? [String: Any] }
        self.threads = threads
        self.crashedThreadIndex = threads.firstIndex { $0[.crashed] == true } ?? 0

        super.init()
    }

    @objc
    public func convertReportToEvent() -> Event? {
        // TODO: Does this need to catch NSExceptions like the ObjC version? Use the shim if so
        let event = Event(level: .fatal)

        let reportMeta: [String: Any]? = report[.report]
        if let ts: NSNumber = reportMeta?[.timestamp] {
            event.timestamp = Date(timeIntervalSince1970: ts.doubleValue)
        } else if let ts: String = reportMeta?[.timestamp] {
            event.timestamp = sentry_fromIso8601String(ts)
        }

        let convertedThreads = convertThreads()
        event.threads = convertedThreads
        event.debugMeta = debugMeta(for: convertedThreads)
        event.exceptions = convertExceptions()

        event.dist = if let dist = userContext["dist"] as? String {
            dist
        } else if let appBuild = userContext["app_build"] as? String {
            appBuild
        } else {
            nil
        }

        event.environment = userContext["environment"] as? String

        var context = userContext["context"] as? [String: [String: Any]] ?? [:]
        if let traceContext = userContext["traceContext"] as? [String: Any] {
            context["trace"] = traceContext
        }

        var appContext = context["app"] ?? [:]
        appContext["in_foreground"] = applicationStats?[.appInFG]
        appContext["is_active"] = applicationStats?[.appActive]
        context["app"] = appContext
        event.context = context

        event.extra = userContext["extra"] as? [String: Any]
        event.tags = userContext["tags"] as? [String: String]

        event.user = convertUser()
        event.breadcrumbs = convertBreadcrumbs()

        event.releaseName = if let release = userContext["release"] as? String {
            release
        } else if
            let appIdentifier = appContext["app_identifier"] as? String,
            let appVersion = appContext["app_version"] as? String,
            let appBuild = appContext["app_build"] as? String {
            // We want to set the release and dist to the version from the crash report
            // itself otherwise it can happend that we have two different version when
            // the app crashes right before an app update #218 #219
            "\(appIdentifier)@\(appVersion)+\(appBuild)"
        } else {
            nil
        }

        return event
    }

    private func convertUser() -> User? {
        guard
            let storedUser = userContext["user"] as? [String: Any]
        else { return nil }

        let user = User()
        user.userId = storedUser["id"] as? String
        user.email = storedUser["email"] as? String
        user.username = storedUser["username"] as? String
        user.data = storedUser["data"] as? [String: Any]

        return user
    }

    private func convertBreadcrumbs() -> [Breadcrumb] {
        guard
            let storedCrumbs = userContext["breadcrumbs"] as? [[String: Any]]
        else { return [] }

        return storedCrumbs.map { stored in
            let crumb = Breadcrumb(
                level: sentryLevel(from: stored["level"] as? String),
                category: stored["category"] as? String ?? "default"
            )

            crumb.message = stored["message"] as? String
            crumb.type = stored["type"] as? String
            crumb.origin = stored["origin"] as? String

            if let ts = stored["timestamp"] as? String {
                crumb.timestamp = sentry_fromIso8601String(ts)
            }
            crumb.data = stored["data"] as? [String: Any]

            return crumb
        }
    }

    private func sentryLevel(from string: String?) -> SentryLevel {
        switch string {
        case "fatal":       .fatal
        case "warning":     .warning
        case "info", "log": .info
        case "debug":       .debug
        default:            .error
        }
    }

    private func rawStackTrace(for index: Int) -> [[String: Any]] {
        guard
            let backtrace: [String: Any] = threads[index][.backtrace],
            let contents: [[String: Any]] = backtrace[.contents]
        else { return [] }

        return contents
    }

    private func registers(for threadIndex: Int) -> [String: String] {
        guard
            let registers: [String: Any] = threads[threadIndex][.registers],
            let basic: [String: Any] = registers[.basic]
        else { return [:] }

        // TODO: check if you can bridge these to a Swift type instead
        return basic.mapValues {
            formatHexAddress($0 as? NSNumber)
        }
    }

    private func binaryImage(for address: UInt) -> [String: Any]? {
        binaryImages.first { image in
            let start = image.uintValue(.imageAddress)
            let size = image.uintValue(.imageSize)

            let end = start + size

            return address >= start && address < end
        }
    }

    private func thread(atIndex index: Int) -> SentryThread? {
        guard index < threads.count else { return nil }
        let threadDictionary = threads[index]

        guard let index: NSNumber = threadDictionary[.index] else {
            SentrySDKLog.error("Thread index is not a number: \(threadDictionary["index"], default: "<nil>")")
            return nil
        }

        let thread = SentryThread(threadId: index)
        let stacktrace = stackTrace(for: index.intValue)

        if stacktrace.frames.isEmpty {
            thread.stacktrace = stacktrace
        }

        thread.crashed = threadDictionary[.crashed]
        thread.current = threadDictionary[.currentThread]
        thread.name = threadDictionary[.name] ?? threadDictionary[.dispatchQueue]
        thread.isMain = NSNumber(value: index == 0)

        return thread
    }

    private func stackFrame(at frameIndex: Int, in threadIndex: Int) -> Frame {
        let frameDictionary = rawStackTrace(for: threadIndex)[frameIndex]
        let image = binaryImage(for: frameDictionary.uintValue(.instructionAddr))

        let frame = Frame()
        frame.instructionAddress = formatHexAddress(frameDictionary[.instructionAddr])
        frame.imageAddress = formatHexAddress(image?[.imageAddress])
        frame.package = image?[.name]
        frame.inApp = NSNumber(value: inAppLogic.is(inApp: image?[.name]))

        return frame
    }

    private func stackFrames(for index: Int) -> [Frame] {
        let rawFrames = rawStackTrace(for: index)

        guard !rawFrames.isEmpty else { return [] }

        var frames: [Frame] = []
        var lastFrame: Frame?

        // TODO: I don't love this.
        for i in 0..<rawFrames.count {
            if rawFrames[i].uintValue(.instructionAddr) == SentryCrashSC_ASYNC_MARKER {
                lastFrame?.stackStart = NSNumber(value: true)
                continue
            }
            let frame = stackFrame(at: i, in: index)
            lastFrame = frame
            frames.append(frame)
        }
        return frames.reversed()
    }

    private func stackTrace(for index: Int) -> SentryStacktrace {
        let frames = stackFrames(for: index)
        let stacktrace = SentryStacktrace(frames: frames, registers: registers(for: index))
        stacktrace.fixDuplicateFrames()

        return stacktrace
    }

    private var crashedThread: SentryThread? {
        thread(atIndex: crashedThreadIndex)
    }

    private func debugMeta(from image: [String: Any]) -> DebugMeta {
        let meta = DebugMeta()
        meta.debugID = image[.uuid]
        meta.type = SentryDebugImageType
        // we default to 0 on the server if not sent
        if let vmAddr: NSNumber = image[.imageVmAddress], vmAddr.intValue > 0 {
            meta.imageVmAddress = formatHexAddress(vmAddr)
        }
        meta.imageAddress = formatHexAddress(image[.imageAddress])
        meta.imageSize = image[.imageSize]
        meta.codeFile = image[.name]

        return meta
    }

    private func debugMeta(for threads: [SentryThread]) -> [DebugMeta] {
        let referencedAddresses = Set(
            threads
                .flatMap { $0.stacktrace?.frames ?? [] }
                .compactMap { $0.imageAddress }
        )

        return binaryImages
            .filter { image in
                referencedAddresses.contains(formatHexAddress(image[.imageAddress]))
            }
            .map { debugMeta(from: $0) }
    }

    private func formatHexAddress(_ value: NSNumber?) -> String {
//        precondition(value != nil, "Whoops, turns out this code lives on a bed of assumptions. This one was pooorly made")
        return sentry_formatHexAddress(value)
    }
}

// MARK: - Exception parsing

private extension KSCrashReportConverter {
    func parseNSException(_ ctx: [String: Any]) -> Exception {
        let details: [String: Any] = ctx[.nsException] ?? [:]

        return Exception(
            value: details[.reason] ?? ctx[.reason] ?? "Unknown NSException Reason",
            type: details[.name] ?? " NSException"
        )
    }

    func parseCPPException(_ ctx: [String: Any]) -> Exception {
        let details: [String: Any] = ctx[.cppException] ?? [:]
        let name: String = details[.name] ?? "Unnamed C++ Exception"
        let reason: String = ctx[.reason] ?? "Unknown Reason"

        return Exception(value: "\(name): \(reason)", type: "C++ Exception")
    }

    func parseMachException(_ ctx: [String: Any]) -> Exception {
        let details: [String: Any] = ctx[.mach] ?? [:]
        let exception: NSNumber = details[.exception] ?? NSNumber(value: 0) // TODO: this is an invalid code, instead we should collect times where this _isn't_ an NSNumber and report them somewhere
        let code: NSNumber = details[.code] ?? NSNumber(value: 0) // TODO: this too....
        let subcode: NSNumber = details[.subcode] ?? NSNumber(value: 0) // TODO: once more

        return Exception(
            value: "Exception \(exception), Code: \(code), Subcode \(subcode)",
            type: details[.exceptionName] ?? "Mach Exception"
        )
    }

    func parseSignalException(_ ctx: [String: Any]) -> Exception {
        let details: [String: Any] = ctx[.signal] ?? [:]
        let signal = details[.signal] ?? NSNumber(value: 0) // TODO: sane default please
        let code: NSNumber = details[.code] ?? NSNumber(value: 0) // TODO: what's the sane default for this?

        return Exception(
            value: "Signal \(signal), Code: \(code)",
            type: details[.name] ?? "Signal Exception"
        )
    }

    func parseUserException(_ ctx: [String: Any]) -> Exception {
        let reason = ctx[.reason] ?? "Unknown reason"
        let userReported: [String: Any] = ctx[.userReported] ?? [:]

        if let range = reason.range(of: ":") {
            return Exception(
                // TODO: verify this slice is correct
                value: String(reason[range.upperBound...]).trimmingCharacters(in: .whitespaces),
                type: String(reason[..<range.lowerBound])
            )
        }

        return Exception(value: reason, type: userReported[.name] ?? "User Reported Exception")
    }

    func parseException(_ ctx: [String: Any]) -> (Exception, ExceptionType) {
        let unknownException = Exception(value: "Unknown Exception", type: "Unknown Exception")

        let exception: Exception
        let exceptionType: ExceptionType

        if let type: String = ctx[.type] {
            exceptionType = ExceptionType(rawValue: type)

            switch exceptionType {
            case .nsException:
                exception = parseNSException(ctx)
            case .cppException:
                exception = parseCPPException(ctx)
            case .mach:
                exception = parseMachException(ctx)
            case .signal:
                exception = parseSignalException(ctx)
            case .user:
                exception = parseUserException(ctx)
            case .deadlock, .memoryTermination:
                // Currently unsupported
                SentrySDKLog.debug("Found an unhandled exception type: \(exceptionType)")
                exception = Exception(value: "Unknown Exception", type: "Unknown Exception")
            default:
                SentrySDKLog.debug("Found an unhandled exception type: \(exceptionType)")
                exception = Exception(value: "Unknown Exception", type: "Unknown Exception")
            }
        } else {
            exception = unknownException
            exceptionType = .unknown
        }

        enhanceValueFromNotableAddresses(of: exception)

        return (exception, exceptionType)
    }

    func convertExceptions() -> [Exception]? {
        guard let ctx = exceptionContext else { return nil }

        let (exception, exceptionType) = parseException(ctx)

        let crashInfoMessages = crashInfoMessagesFromBinaryImages()

        // crash_info_message is a shared buffer that may hold unrelated Swift runtime warnings from
        // earlier in the process. Only use it to override for mach/signal, where it IS the crash cause.
        // For nsexception, cpp_exception, user the exception context is authoritative—overwriting
        // would replace the real reason with stale or unrelated text.
        if [.mach, .signal].contains(exceptionType) && !crashInfoMessages.isEmpty {
            exception.value = crashInfoMessages.first
        }

        exception.mechanism = mechanism(of: exceptionType.rawValue)

        if
            [.nsException, .cppException, .user].contains(exceptionType),
            let mech = exception.mechanism,
            !crashInfoMessages.isEmpty {
            var data = mech.data ?? [:]
            data["crash_info_messages"] = crashInfoMessages
            mech.data = data
        }

        let crashed = crashedThread
        exception.threadId = crashed?.threadId
        exception.stacktrace = crashed?.stacktrace

        if
            let value = exception.value,
            let diagnosis,
            !diagnosis.isEmpty,
            !diagnosis.contains(value) {
            exception.value = "\(value) >\n\(diagnosis)"
        }

        return [exception]
    }

    private func isStackOverflow(thread: [String: Any]) -> Bool {
        guard
            let stack: [String: Any] = thread[.stack],
            let overflow: NSNumber = stack[.overflow]
        else { return false }

        return overflow.boolValue
    }

    private func enhanceValueFromNotableAddresses(of exception: Exception) {
        guard
            !threads.isEmpty,
            crashedThreadIndex >= 0,
            crashedThreadIndex < threads.count
        else { return }

        let crashedThread = threads[crashedThreadIndex]

        // Stack overflow crashes can leave unrelated app data near the stack pointer. Don't promote
        // those memory-introspection strings to the exception value.
        if isStackOverflow(thread: crashedThread) {
            SentrySDKLog.debug(
                "Skipping notable address exception value enhancement because crashed thread stack.overflow is true"
            )
            return
        }

        guard let notableAddresses: [String: Any] = crashedThread[.notableAddresses] else { return }

        let reasons = notableAddresses.values
            .compactMap { $0 as? [String: Any] } // cast to 'dictionary'
            .filter { $0[.type, String.self] == "string" } // filter out non-string types
            .compactMap { $0[.value, String.self] }
            .filter { $0.components(separatedBy: "/").count < 3 }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

        if !reasons.isEmpty {
            exception.value = reasons
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .joined(separator: " > ")
        }
    }

    private func crashInfoMessagesFromBinaryImages() -> [String] {
        binaryImages
            .filter { $0[.name, String.self]?.contains("libswiftCore.dylib") == true }
            .flatMap { image in
                [
                    image[.imageCrashInfoMessage, String.self],
                    image[.imageCrashInfoMessage2, String.self]
                ].compactMap { $0 }
            }
    }

    private func mechanism(of type: String) -> Mechanism? {
        let mech = Mechanism(type: type)

        guard
            let ctx = exceptionContext,
            let machDict: [String: Any] = ctx[.mach]
        else { return mech }

        mech.handled = NSNumber(value: false)

        let meta = MechanismContext()

        meta.machException = [
            "name": machDict[.exceptionName, String.self] as Any,
            "exception": machDict[.exception, UInt64.self] as Any,
            "subcode": machDict[.subcode, UInt64.self] as Any,
            "code": machDict[.code, UInt64.self] as Any
        ]

        if let signalDict: [String: Any] = ctx[.signal] {
            meta.signal = [
                "number": signalDict[.signal, UInt64.self] as Any,
                "code": signalDict[.code, UInt64.self] as Any,
                "code_name": signalDict[.codeName, String.self] as Any,
                "name": signalDict[.name, String.self] as Any
            ]
        }

        mech.meta = meta

        if let addr: NSNumber = ctx[.address], addr.intValue > 0 {
            mech.data = ["relevant_address": formatHexAddress(addr)]
        }

        return mech
    }

    private func convertThreads() -> [SentryThread] {
        (0..<threads.count).compactMap { i in
            guard let t = thread(atIndex: i), t.stacktrace != nil else { return nil }
            return t
        }
    }
}
// swiftlint:enable missing_docs
