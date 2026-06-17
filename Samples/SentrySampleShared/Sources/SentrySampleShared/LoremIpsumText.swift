import Foundation

public class BundleResourceProvider: NSObject {
    public static var loremIpsumTextFilePath: String? {
#if SWIFT_PACKAGE
        Bundle.module.path(forResource: "LoremIpsum", ofType: "txt")
#else
        Bundle(for: self).path(forResource: "LoremIpsum", ofType: "txt")
#endif
    }

    @objc public static var screenshotURL: URL? {
#if SWIFT_PACKAGE
        Bundle.module.url(forResource: "screenshot", withExtension: "png")
#else
        Bundle(for: self).url(forResource: "screenshot", withExtension: "png")
#endif
    }
}
