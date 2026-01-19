class TestRedactOptions: SentryRedactOptions {
    var maskedViewClasses: [AnyClass]
    var unmaskedViewClasses: [AnyClass]
    var maskAllText: Bool
    var maskAllImages: Bool
    var excludedViewClasses: Set<String>
    var includedViewClasses: Set<String>

    init(
        maskAllText: Bool = true,
        maskAllImages: Bool = true,
        maskedViewClasses: [AnyClass] = [],
        unmaskedViewClasses: [AnyClass] = [],
        excludedViewClasses: Set<String> = [],
        includedViewClasses: Set<String> = []
    ) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.maskedViewClasses = maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses
        self.excludedViewClasses = excludedViewClasses
        self.includedViewClasses = includedViewClasses
    }
}
