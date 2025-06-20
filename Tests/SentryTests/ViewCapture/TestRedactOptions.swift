class TestRedactOptions: SentryRedactOptions {
    var maskedViewClasses: [AnyClass]
    var unmaskedViewClasses: [AnyClass]
    var maskAllText: Bool
    var maskAllImages: Bool

    init(maskAllText: Bool = true, maskAllImages: Bool = true) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        maskedViewClasses = []
        unmaskedViewClasses = []
    }
}
