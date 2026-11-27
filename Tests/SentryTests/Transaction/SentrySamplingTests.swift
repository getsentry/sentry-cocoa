@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class SentrySamplingTests: XCTestCase {

    private var originalRandom: SentryRandomProtocol?

    override func setUp() {
        super.setUp()
        originalRandom = SentryDependencyContainer.sharedInstance().random
    }

    override func tearDown() {
        if let originalRandom {
            SentryDependencyContainer.sharedInstance().random = originalRandom
        }
        super.tearDown()
    }

    func testSampleTrace_whenTransactionAlreadySampled_shouldReturnTransactionDecision() {
        // -- Arrange --
        setRandom(0.9)
        let options = Options()
        options.tracesSampler = { _ in 1.0 }
        let transactionContext = TransactionContext(name: "name", operation: "operation", sampled: .no, sampleRate: 0.3, sampleRand: 0.6)

        // -- Act --
        let decision = SentrySampling.sampleTrace(SamplingContext(transactionContext: transactionContext), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .no)
        XCTAssertEqual(decision.sampleRate, 0.3)
        XCTAssertEqual(decision.sampleRand, 0.6)
    }

    func testSampleTrace_whenSamplerReturnsRateAboveRandom_shouldSample() {
        // -- Arrange --
        setRandom(0.5)
        let options = Options()
        options.tracesSampleRate = 0
        options.tracesSampler = { _ in 0.5 }

        // -- Act --
        let decision = SentrySampling.sampleTrace(undecidedSamplingContext(), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .yes)
        XCTAssertEqual(decision.sampleRate, 0.5)
        XCTAssertEqual(decision.sampleRand, 0.5)
    }

    func testSampleTrace_whenSamplerReturnsRateBelowRandom_shouldNotSample() {
        // -- Arrange --
        setRandom(0.51)
        let options = Options()
        options.tracesSampleRate = 1
        options.tracesSampler = { _ in 0.5 }

        // -- Act --
        let decision = SentrySampling.sampleTrace(undecidedSamplingContext(), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .no)
        XCTAssertEqual(decision.sampleRate, 0.5)
        XCTAssertEqual(decision.sampleRand, 0.51)
    }

    func testSampleTrace_whenSamplerReturnsNil_shouldUseTracesSampleRate() {
        // -- Arrange --
        setRandom(0.2)
        let options = Options()
        options.tracesSampleRate = 0.4
        options.tracesSampler = { _ in nil }

        // -- Act --
        let decision = SentrySampling.sampleTrace(undecidedSamplingContext(), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .yes)
        XCTAssertEqual(decision.sampleRate, 0.4)
        XCTAssertEqual(decision.sampleRand, 0.2)
    }

    func testSampleTrace_whenSamplerReturnsInvalidRate_shouldUseTracesSampleRate() {
        // -- Arrange --
        setRandom(0.2)
        let options = Options()
        options.tracesSampleRate = 0.1
        options.tracesSampler = { _ in 1.1 }

        // -- Act --
        let decision = SentrySampling.sampleTrace(undecidedSamplingContext(), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .no)
        XCTAssertEqual(decision.sampleRate, 0.1)
        XCTAssertEqual(decision.sampleRand, 0.2)
    }

    func testSampleTrace_whenSamplerReturnsRate_shouldIgnoreParentDecision() {
        // -- Arrange --
        setRandom(0.9)
        let options = Options()
        options.tracesSampler = { _ in 0.5 }
        let transactionContext = TransactionContext(name: "name", operation: "operation")
        transactionContext.parentSampled = .yes

        // -- Act --
        let decision = SentrySampling.sampleTrace(SamplingContext(transactionContext: transactionContext), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .no)
        XCTAssertEqual(decision.sampleRate, 0.5)
        XCTAssertEqual(decision.sampleRand, 0.9)
    }

    func testSampleTrace_whenParentSampledAndNoSampler_shouldReturnParentDecision() {
        // -- Arrange --
        setRandom(0.9)
        let options = Options()
        options.tracesSampleRate = 0
        let transactionContext = TransactionContext(name: "name", operation: "operation")
        transactionContext.parentSampled = .yes
        transactionContext.sampleRate = 0.3
        transactionContext.sampleRand = 0.6

        // -- Act --
        let decision = SentrySampling.sampleTrace(SamplingContext(transactionContext: transactionContext), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .yes)
        XCTAssertEqual(decision.sampleRate, 0.3)
        XCTAssertEqual(decision.sampleRand, 0.6)
    }

    func testSampleTrace_whenNoTracesSampleRate_shouldNotSample() {
        // -- Arrange --
        setRandom(0)
        let options = Options()
        options.tracesSampleRate = nil

        // -- Act --
        let decision = SentrySampling.sampleTrace(undecidedSamplingContext(), options: options)

        // -- Assert --
        XCTAssertEqual(decision.decision, .no)
        XCTAssertNil(decision.sampleRate)
        XCTAssertNil(decision.sampleRand)
    }

    func testSampleTrace_whenOptionsNil_shouldNotSample() {
        // -- Arrange --
        setRandom(0)

        // -- Act --
        let decision = SentrySampling.sampleTrace(undecidedSamplingContext(), options: nil)

        // -- Assert --
        XCTAssertEqual(decision.decision, .no)
        XCTAssertNil(decision.sampleRate)
        XCTAssertNil(decision.sampleRand)
    }

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    func testSampleProfileSession_whenRandomAtRate_shouldSample() {
        // -- Arrange --
        setRandom(0.5)

        // -- Act --
        let decision = SentrySampling.sampleProfileSession(0.5)

        // -- Assert --
        XCTAssertEqual(decision.decision, .yes)
        XCTAssertEqual(decision.sampleRate, 0.5)
        XCTAssertEqual(decision.sampleRand, 0.5)
    }

    func testSampleProfileSession_whenRandomAboveRate_shouldNotSample() {
        // -- Arrange --
        setRandom(0.51)

        // -- Act --
        let decision = SentrySampling.sampleProfileSession(0.5)

        // -- Assert --
        XCTAssertEqual(decision.decision, .no)
        XCTAssertEqual(decision.sampleRate, 0.5)
        XCTAssertEqual(decision.sampleRand, 0.51)
    }
#endif // !(os(watchOS) || os(tvOS) || os(visionOS))

    private func setRandom(_ value: Double) {
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: value)
    }

    private func undecidedSamplingContext() -> SamplingContext {
        return SamplingContext(transactionContext: TransactionContext(name: "name", operation: "operation"))
    }
}
