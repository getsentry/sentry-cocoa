import UIKit

struct ColorUtils {
    static func getTextColor(_ color: CGColor?, isDarkBackground: Bool?) -> UIColor {
        if let color = colorFromCGColor(color) {
            return color
        } else {
            return (isDarkBackground ?? false) ? .white : .black
        }
    }

    static func colorFromCGColor(_ color: CGColor?) -> UIColor? {
        color.flatMap { UIColor(cgColor: $0) }
    }
}
