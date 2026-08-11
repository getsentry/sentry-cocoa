#if os(iOS) || os(tvOS)

@_spi(Private) @testable import Sentry

@_spi(Private) public class TestSentryViewPhotographer: SentryViewPhotographer {
    public override init(
        renderer: SentryViewRenderer,
        redactOptions: any SentryRedactOptions,
        enableMaskRendererV2: Bool = false,
        dateProvider: SentryCurrentDateProvider = SentryDefaultCurrentDateProvider()
    ) {
        super.init(
            renderer: renderer,
            redactOptions: redactOptions,
            enableMaskRendererV2: enableMaskRendererV2,
            dateProvider: dateProvider
        )
    }
}
#endif
