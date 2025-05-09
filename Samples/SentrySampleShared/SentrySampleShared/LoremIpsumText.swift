import Foundation

public class BundleResourceProvider: NSObject {
    public static var loremIpsumTextFilePath: String? {
        Bundle(for: self).path(forResource: "LoremIpsum", ofType: "txt")
    }

    @objc public static var screenshotURL: URL? {
        Bundle(for: self).url(forResource: "screenshot", withExtension: "png")
    }
}
