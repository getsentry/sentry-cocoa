import Foundation

class LoremIpsumTextProvider {
    static func loremIpsumTextFilePath() -> String? {
        Bundle(for: self).path(forResource: "LoremIpsum", ofType: "txt")
    }
}
