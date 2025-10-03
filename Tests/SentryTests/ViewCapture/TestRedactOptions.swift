class TestRedactOptions: SentryRedactOptions {
    var maskedViewClasses: [AnyClass]
    var unmaskedViewClasses: [AnyClass]
    var maskAllText: Bool
    var maskAllImages: Bool

    init(
        maskAllText: Bool = true,
        maskAllImages: Bool = true,
        maskedViewClasses: [AnyClass] = [],
        unmaskedViewClasses: [AnyClass] = []
    ) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.maskedViewClasses = maskedViewClasses
        self.unmaskedViewClasses = maskedViewClasses
    }
}
