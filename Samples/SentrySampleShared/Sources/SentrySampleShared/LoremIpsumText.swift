import Foundation

public class BundleResourceProvider: NSObject {
    public static var loremIpsumTextFilePath: String? {
        Bundle.module.path(forResource: "LoremIpsum", ofType: "txt")
    }

    @objc public static var screenshotURL: URL? {
        Bundle.module.url(forResource: "screenshot", withExtension: "png")
    }
}
