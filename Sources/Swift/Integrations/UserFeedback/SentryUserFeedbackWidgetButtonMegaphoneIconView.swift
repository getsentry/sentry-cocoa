import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOS 13.0, *)
class SentryUserFeedbackWidgetButtonMegaphoneIconView: UIView {
    init(config: SentryUserFeedbackConfiguration) {
        super.init(frame: .zero)
    
        let svgLayer = CAShapeLayer()
        svgLayer.path = megaphoneShape
        svgLayer.fillColor = UIColor.clear.cgColor
        
        if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            svgLayer.strokeColor = config.darkTheme.foreground.cgColor
        } else {
            svgLayer.strokeColor = config.theme.foreground.cgColor
        }
        
        layer.addSublayer(svgLayer)
        translatesAutoresizingMaskIntoConstraints = false
        
        var transform = CATransform3DIdentity
        if config.scaleFactor != 1 {
            transform = CATransform3DConcat(transform, CATransform3DMakeScale(config.scaleFactor, config.scaleFactor, 0))
        }
        
        if SentryLocale.isRightToLeftLanguage() {
            transform = CATransform3DConcat(transform, CATransform3DMakeScale(-1, 1, 1))
        }
        
        layer.transform = transform
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //swiftlint:disable function_body_length
    lazy var megaphoneShape: CGPath = {
        let path = CGMutablePath()
                
        path.move(to: CGPoint(x: 1, y: 3))
        path.addLine(to: CGPoint(x: 7, y: 3))
        path.addLine(to: CGPoint(x: 10, y: 1))
        path.addLine(to: CGPoint(x: 12, y: 1))
        path.addLine(to: CGPoint(x: 12, y: 11))
        path.addLine(to: CGPoint(x: 10, y: 11))
        path.addLine(to: CGPoint(x: 7, y: 9))
        path.addLine(to: CGPoint(x: 1, y: 9))
        path.closeSubpath()
        
        path.addRect(CGRect(x: 2, y: 9, width: 3.5, height: 6))
        
        path.move(to: CGPoint(x: 12, y: 6))
        path.addRelativeArc(center: CGPoint(x: 12, y: 6), radius: 3, startAngle: -(.pi / 2), delta: .pi)
        
        return path
    }()
    //swiftlint:enable function_body_length
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
