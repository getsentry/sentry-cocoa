class TestRedactOptions: SentryRedactOptions {
    var maskedViewClasses: [AnyClass]
    var unmaskedViewClasses: [AnyClass]
    var maskAllText: Bool
    var maskAllImages: Bool
    var viewTypesIgnoredFromSubtreeTraversal: Set<String>

    init(
        maskAllText: Bool = true,
        maskAllImages: Bool = true,
        maskedViewClasses: [AnyClass] = [],
        unmaskedViewClasses: [AnyClass] = [],
        viewTypesIgnoredFromSubtreeTraversal: Set<String> = []
    ) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.maskedViewClasses = maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses
        self.viewTypesIgnoredFromSubtreeTraversal = viewTypesIgnoredFromSubtreeTraversal
    }
}
