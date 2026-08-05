#if ENABLE_KSCRASH

extension SentryKSCrash {
    protocol QueryProvider {
        associatedtype Querying: SentryKSCrashQuerying
        var kscrashQuery: Querying { get }
    }

    // The compiler is unable to emit declarations for ObjC types nested in Swift types that
    // cannot be represented in ObjC (i.e. enum -> class). So in order to keep the 'shape' of
    // the SentryKSCrash API, we declare them as typealiases here
    /// An ObjC-accessible class that surfaces live KSCrash crash state to ObjC callers  without littering the SentryKSCrash types with `@objc`.
    @_spi(Private) public typealias Query = SentryKSCrashQuery
    /// Allows querying the state of the crash reporter.
    @_spi(Private) public typealias Querying = SentryKSCrashQuerying
}

/// Allows querying the state of the crash reporter.
@_spi(Private)
@objc(SentryKSCrashQuerying)
public protocol SentryKSCrashQuerying: SentryCrashReporterState {
}

/// An ObjC-accessible class that surfaces live KSCrash crash state to ObjC callers  without littering the SentryKSCrash types with `@objc`.
@_spi(Private)
@objc(SentryKSCrashQuery)
public final class SentryKSCrashQuery: NSObject, SentryKSCrashQuerying {
    private let _installed: () -> Bool
    private let _crashedLastLaunch: () -> Bool

    init(installer: some SentryKSCrash.Installing) {
        _installed = { installer.installed }
        _crashedLastLaunch = { installer.crashedLastLaunch }
    }

    // swiftlint:disable missing_docs
    @objc public var installed: Bool { _installed() }
    @objc public var crashedLastLaunch: Bool { _crashedLastLaunch() }
    // swiftlint:enable missing_docs
}
#endif
