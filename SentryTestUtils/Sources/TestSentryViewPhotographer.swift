#if os(iOS) || os(tvOS)

@_spi(Private) @testable import Sentry

@_spi(Private) public class TestSentryViewPhotographer: SentryViewPhotographer {
    public override init(
        renderer: SentryViewRenderer,
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
