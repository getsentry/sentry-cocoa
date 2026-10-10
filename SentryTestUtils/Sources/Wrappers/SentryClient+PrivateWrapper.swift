#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

// Keep erased declarations distinct at the Clang boundary while preserving the typed SDK
// names used by tests. Calls still dispatch to the original Objective-C selectors.
extension SentryClientInternal {
    @_spi(Private) @nonobjc public convenience init(
        options: Options,
        dateProvider: SentryCurrentDateProvider,
        transportAdapter: SentryTransportAdapter,
        fileManager: SentryFileManager,
        threadInspector: SentryDefaultThreadInspector,
        debugImageProvider: SentryDebugImageProvider,
        random: SentryRandomProtocol,
        locale: Locale,
        timezone: TimeZone,
        eventContextEnricher: SentryEventContextEnricher,
        binaryImageCache: SentryBinaryImageCache,
        dispatchQueueWrapper: SentryDispatchQueueWrapper
    ) {
        self.init(
            testOptions: options,
            dateProvider: dateProvider,
            transportAdapter: transportAdapter,
            fileManager: fileManager,
            threadInspector: threadInspector,
            debugImageProvider: debugImageProvider,
            random: random,
            locale: locale,
            timezone: timezone,
            eventContextEnricher: eventContextEnricher,
            binaryImageCache: binaryImageCache,
            dispatchQueueWrapper: dispatchQueueWrapper
        )
    }

    // Xcode imports these typed methods already; only SwiftPM needs the forwarding overloads.
    #if SWIFT_PACKAGE
    @_spi(Private) @nonobjc public func captureFatalEvent(_ event: Event, with session: SentrySession, with scope: Scope) -> SentryId {
        test_captureFatalEvent(event, session: session, scope: scope)
    }

    @_spi(Private) @nonobjc public func capture(_ event: SentryReplayEvent, replayRecording: SentryReplayRecording, video: URL, with scope: Scope) {
        test_captureReplayEvent(event, recording: replayRecording, video: video, scope: scope)
    }

    @_spi(Private) @nonobjc public func store(_ envelope: SentryEnvelope) {
        test_storeEnvelope(envelope)
    }
    #endif

    // Xcode already imports the typed property. SwiftPM uses the SDK's existing ObjC bridge.
    #if SWIFT_PACKAGE
    public var options: Options {
        get { requireTestBridgeValue(getOptions()) }
        set { setOptions(newValue) }
    }
    #endif

    @_spi(Private) public var fileManager: SentryFileManager {
        get { requireTestBridgeValue(test_fileManager()) }
        set { test_setFileManager(newValue) }
    }
}
