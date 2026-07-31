#if ENABLE_KSCRASH
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashInstallations
internal import _SentryPrivate

extension SentryKSCrash {
    protocol QueryProvider {
        associatedtype Querying: SentryKSCrash.Querying

        var kscrashQuery: Querying { get }
    }
}

extension SentryKSCrash {
    /// Allows querying the state of the crash reporter
    @objc(SentryKSCrashQuerying)
    public protocol Querying: NSObjectProtocol {
        /// Whether KSCrash has been successfully installed this session.
        @objc var installed: Bool { get }
        /// Whether KSCrash crashed on the previous launch.
        @objc var crashedLastLaunch: Bool { get }
    }
}

extension SentryKSCrash {
    /// An ObjC-accessible class that surfaces live KSCrash crash state to ObjC callers
    /// without adding `@objc` to `SentryKSCrash.Installer`.
    @_spi(Private)
    @objc(SentryKSCrashQuery)
    final public class Query: NSObject, Querying {
        private let installer: any Installing

        init(installer: some Installing) {
            self.installer = installer
        }

        // swiftlint:disable missing_docs
        @objc
        public var installed: Bool { installer.installed }

        @objc
        public var crashedLastLaunch: Bool { installer.crashedLastLaunch }
        //swiftlint:enable missing_docs
    }
}
#endif
