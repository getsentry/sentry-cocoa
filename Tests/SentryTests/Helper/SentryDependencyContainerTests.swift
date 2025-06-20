@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

final class SentryDependencyContainerTests: XCTestCase {

    private static let dsn = TestConstants.dsnAsString(username: "SentryDependencyContainerTests")

    override func tearDown() {
        SentryDependencyContainer.reset()
    }

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testReset_CallsFramesTrackerStop() throws {
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker
        framesTracker.start()
        SentryDependencyContainer.reset()

        XCTAssertFalse(framesTracker.isRunning)
    }

    func testGetANRTrackerV2() {
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance is SentryANRTrackerV2)

        SentryDependencyContainer.reset()

    }

    func testGetANRTrackerV1() {
        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance is SentryANRTrackerV1)

        SentryDependencyContainer.reset()
    }

    func testGetANRTrackerV2AndThenV1_FirstCalledVersionStaysTheSame() {
        let instance1 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance1 is SentryANRTrackerV2)

        let instance2 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance2 is SentryANRTrackerV2)

        SentryDependencyContainer.reset()
    }

    func testGetANRTrackerV1AndThenV2_FirstCalledVersionStaysTheSame() {
        let instance1 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: false)
        XCTAssertTrue(instance1 is SentryANRTrackerV1)

        let instance2 = SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true)
        XCTAssertTrue(instance2 is SentryANRTrackerV1)

        SentryDependencyContainer.reset()
    }

#endif

    func testGetANRTracker_ReturnsV1() {

        let instance = SentryDependencyContainer.sharedInstance().getANRTracker(2.0)
        XCTAssertTrue(instance is SentryANRTrackerV1)

        SentryDependencyContainer.reset()
    }

    /**
     * This test helps to find threading issues. If you run it once it detects obvious threading issues. Some rare edge cases
     * only happen if you run this 1000 times in a row or increase the test iterations to 100k.
     * While this testing scenario is atypical for production, we heavily call reset in our tests and saw crashes and problems
     * related to that. Therefore, it makes sense to ensure thread safety.
     */
    func testThreadSafety_ResetAndAccessProperties() {

        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let iterations = 100

        let queue = DispatchQueue(label: "SentryDependencyContainerTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let expectation = expectation(description: "testThreadSafety_ResetAndAccessProperties")
        expectation.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {

            queue.async {

                for _ in 0...10 {
                    // This is a quite unrealistic scenario, but it helps to find threading issues.
                    SentryDependencyContainer.reset()
                }

                for _ in 0...10 {
                    // Init Dependencies
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchQueueWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().random)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().threadWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().binaryImageCache)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dateProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().notificationCenterWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().extraContextProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().processInfoWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().crashWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().sysctlWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().rateLimits)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().reachability)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().uiDeviceWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().application)
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

                    // Lazy Dependencies
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().fileManager)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().appStateManager)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().threadInspector)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().fileIOTracker)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().crashReporter)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().scopeContextPersistentStore)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().debugImageProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getANRTracker(2.0))

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getANRTracker(2.0, isV2Enabled: true))
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().systemWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchFactory)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().dispatchQueueProvider)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().timerFactory)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().swizzleWrapper)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().framesTracker)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getScreenshotProvider(for: .init()))
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().viewHierarchyProvider)

                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker)
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

#if os(iOS) || os(macOS)
                    if #available(iOS 15.0, macOS 12.0, *) {
                        XCTAssertNotNil(SentryDependencyContainer.sharedInstance().metricKitManager)
                    }
#endif // os(iOS) || os(macOS)

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().getWatchdogTerminationBreadcrumbProcessor(withMaxBreadcrumbs: 10))
                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().watchdogTerminationContextProcessor)
#endif

                    XCTAssertNotNil(SentryDependencyContainer.sharedInstance().globalEventProcessor)
                }

                expectation.fulfill()
            }
        }

        queue.activate()

        wait(for: [expectation], timeout: 10)
    }

    func testScopeContextStore_shouldReturnSameInstance() throws {
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let container = SentryDependencyContainer.sharedInstance()

        // -- Act --
        let scopeContextStore1 = container.scopeContextPersistentStore
        let scopeContextStore2 = container.scopeContextPersistentStore

        // -- Assert --
        XCTAssertIdentical(scopeContextStore1, scopeContextStore2)
    }

    func testGetWatchdogTerminationBreadcrumbProcessorWithMaxBreadcrumbs_shouldReturnNewInstancePerCall() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let container = SentryDependencyContainer.sharedInstance()

        // -- Act --
        let processor1 = container.getWatchdogTerminationBreadcrumbProcessor(withMaxBreadcrumbs: 10)
        let processor2 = container.getWatchdogTerminationBreadcrumbProcessor(withMaxBreadcrumbs: 5)

        // -- Assert --
        XCTAssertNotIdentical(processor1, processor2)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and macOS platforms.")
#endif
    }

    func testGetWatchdogTerminationBreadcrumbProcessorWithMaxBreadcrumbs_shouldUseParameters() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let container = SentryDependencyContainer.sharedInstance()

        // -- Act --
        let processor1 = container.getWatchdogTerminationBreadcrumbProcessor(withMaxBreadcrumbs: 10)
        let processor2 = container.getWatchdogTerminationBreadcrumbProcessor(withMaxBreadcrumbs: 5)

        // -- Assert --
        // This assertion relys on internal implementation details of the processor.
        // It is best practice not to rely on internal implementation details.
        // There is no other way to test this, because the max breadcrumbs property is private.
        XCTAssertEqual(Dynamic(processor1).maxBreadcrumbs, 10)
        XCTAssertEqual(Dynamic(processor2).maxBreadcrumbs, 5)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and macOS platforms.")
#endif
    }

    func testSentryWatchdogTerminationContextProcessor_shouldReturnSameInstance() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let container = SentryDependencyContainer.sharedInstance()

        // -- Act --
        let processor1 = container.watchdogTerminationContextProcessor
        let processor2 = container.watchdogTerminationContextProcessor

        // -- Assert --
        XCTAssertIdentical(processor1, processor2)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and macOS platforms.")
#endif
    }

    func testSentryWatchdogTerminationContextProcessor_shouldUseLowPriorityQueue() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let container = SentryDependencyContainer.sharedInstance()
        let dispatchFactory = TestDispatchFactory()
        container.dispatchFactory = dispatchFactory

        // -- Act --
        // Accessing the processor will trigger the creation of a new instance
        let _ = container.watchdogTerminationContextProcessor

        // -- Assert --
        let dispatchFactoryInvocation = try XCTUnwrap(dispatchFactory.createLowPriorityQueueInvocations.first)
        XCTAssertEqual(dispatchFactoryInvocation.name, "io.sentry.watchdog-termination-tracking.context-processor")
        XCTAssertEqual(dispatchFactoryInvocation.relativePriority, 0)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and macOS platforms.")
#endif
    }

    func testGetScreenshotProviderForOptions_sameScreenshotOptionsInstance_shouldReturnSameInstancePerCall() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let sut = SentryDependencyContainer.sharedInstance()

        // -- Act --
        let provider1 = sut.getScreenshotProvider(for: options.screenshot)
        let provider2 = sut.getScreenshotProvider(for: options.screenshot)

        // -- Assert --
        XCTAssertIdentical(provider1, provider2)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and Mac Catalyst platforms.")
#endif
    }

    func testGetScreenshotProviderForOptions_sameScreenshotOptionsHash_shouldReturnSameInstancePerCall() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let sut = SentryDependencyContainer.sharedInstance()

        let options1 = SentryScreenshotOptions()
        let options2 = SentryScreenshotOptions()

        // Pre-condition check
        XCTAssertEqual(options1.hashValue, options2.hashValue, "Both options should have the same hash value.")

        // -- Act --
        let provider1 = sut.getScreenshotProvider(for: options1)
        let provider2 = sut.getScreenshotProvider(for: options2)

        // -- Assert --
        XCTAssertIdentical(provider1, provider2)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and Mac Catalyst platforms.")
#endif
    }

    func testGetScreenshotProviderForOptions_differentScreenshotOptions_shouldReturnDifferentInstancePerCall() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let sut = SentryDependencyContainer.sharedInstance()

        let options1 = SentryScreenshotOptions(
            enableViewRendererV2: true
        )
        let options2 = SentryScreenshotOptions(
            enableViewRendererV2: false
        )

        // Pre-condition check
        XCTAssertNotEqual(options1.hashValue, options2.hashValue, "Both options should have different hash values.")

        // -- Act --
        let provider1 = sut.getScreenshotProvider(for: options1)
        let provider2 = sut.getScreenshotProvider(for: options2)

        // -- Assert --
        XCTAssertNotIdentical(provider1, provider2)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and Mac Catalyst platforms.")
#endif
    }

    /// This test ensures that if all references to the screenshot provider are deallocated and the container is not keeping strong references.
    func testGetScreenshotProviderForOptions_allReferencesDeallocated_shouldCreateNewInstance() throws {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        // -- Arrange --
        let options = Options()
        options.dsn = SentryDependencyContainerTests.dsn
        SentrySDK.setStart(options)

        let sut = SentryDependencyContainer.sharedInstance()

        // -- Act --
        var provider1MemoryAddress: UnsafeMutableRawPointer?
        var provider2MemoryAddress: UnsafeMutableRawPointer?

        autoreleasepool {
            var provider1: SentryScreenshotProvider! = sut.getScreenshotProvider(for: options.screenshot)
            provider1MemoryAddress = Unmanaged.passUnretained(provider1).toOpaque()

            var provider2: SentryScreenshotProvider! = sut.getScreenshotProvider(for: options.screenshot)
            provider2MemoryAddress = Unmanaged.passUnretained(provider2).toOpaque()

            provider1 = nil
            provider2 = nil
        }

        let newProvider = sut.getScreenshotProvider(for: options.screenshot)
        let newProviderMemoryAddress = Unmanaged.passUnretained(newProvider).toOpaque()

        // -- Assert --
        XCTAssertEqual(provider1MemoryAddress, provider2MemoryAddress)
        XCTAssertNotEqual(newProviderMemoryAddress, provider1MemoryAddress)
#else
        throw XCTSkip("This test is only applicable for iOS, tvOS, and Mac Catalyst platforms.")
#endif
    }
}
