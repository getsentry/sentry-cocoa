#if canImport(UIKit)

import Foundation
import UIKit

final class UIImageHelper {
    private init() { }
    
    static func averageColor(of image: UIImage, at region: CGRect) -> UIColor {
        let colorImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), 
                                                 format: .init(for: .init(displayScale: 1))).image { context in
            let scaledRegion = region.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))
            
            guard let croppedImage = image.cgImage?.cropping(to: scaledRegion) else {
                UIColor.black.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
                return
            }

            context.cgContext.draw(croppedImage, in: CGRect(x: 0, y: 0, width: 1, height: 1), byTiling: false)
        }
        
        guard
            let pixelData = colorImage.cgImage?.dataProvider?.data,
            let data = CFDataGetBytePtr(pixelData) else { return .black }
        
        let blue = CGFloat(data[0]) / 255.0
        let green = CGFloat(data[1]) / 255.0
        let red = CGFloat(data[2]) / 255.0
        let alpha = CGFloat(data[3]) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

#endif
