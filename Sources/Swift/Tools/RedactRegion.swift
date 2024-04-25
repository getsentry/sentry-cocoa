#if canImport(UIKit)
import Foundation
import UIKit

struct RedactRegion {
    let rect: CGRect
    let color: UIColor?
    
    init(rect: CGRect, color: UIColor? = nil) {
        self.rect = rect
        self.color = color
    }
    
    func splitBySubtracting(region: CGRect) -> [RedactRegion] {
        guard rect.intersects(region) else { return [self] }
        guard !region.contains(rect) else { return [] }
        
        let intersectionRect = rect.intersection(region)
        var resultRegions: [CGRect] = []
        
        // Calculate the top region.
        resultRegions.append(CGRect(x: rect.minX,
                                    y: rect.minY,
                                    width: rect.width,
                                    height: intersectionRect.minY - rect.minY))
        
        // Calculate the bottom region.
        resultRegions.append(CGRect(x: rect.minX,
                                    y: intersectionRect.maxY,
                                    width: rect.width,
                                    height: rect.maxY - intersectionRect.maxY))
        
        // Calculate the left region.
        resultRegions.append(CGRect(x: rect.minX,
                                    y: max(rect.minY, intersectionRect.minY),
                                    width: intersectionRect.minX - rect.minX,
                                    height: min(intersectionRect.maxY, rect.maxY) - max(rect.minY, intersectionRect.minY)))
        
        // Calculate the right region.
        resultRegions.append(CGRect(x: intersectionRect.maxX,
                                    y: max(rect.minY, intersectionRect.minY),
                                    width: rect.maxX - intersectionRect.maxX,
                                    height: min(intersectionRect.maxY, rect.maxY) - max(rect.minY, intersectionRect.minY)))
        
        return resultRegions.filter { !$0.isEmpty }.map { RedactRegion(rect: $0, color: color) }
    }
}
#endif
