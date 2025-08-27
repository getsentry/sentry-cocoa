#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) @testable import Sentry

@_spi(Private) public class TestSentryViewPhotographer: SentryViewPhotographer {
    public override init(
        renderer: SentryViewRenderer = TestSentryViewRenderer(),
        redactOptions: any SentryRedactOptions,
        enableMaskRendererV2: Bool = false
    ) {
        super.init(
            renderer: renderer,
            redactOptions: redactOptions,
            enableMaskRendererV2: enableMaskRendererV2
        )
    }
}
#endif
