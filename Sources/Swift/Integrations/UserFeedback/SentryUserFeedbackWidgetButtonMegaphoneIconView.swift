import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

class SentryUserFeedbackWidgetButtonMegaphoneIconView: UIView {
    init(config: SentryUserFeedbackConfiguration) {
        super.init(frame: .zero)
    
        let svgLayer = CAShapeLayer()
        svgLayer.path = megaphoneShape
        
        func configureLightTheme() {
            svgLayer.fillColor = config.theme.foreground.cgColor
        }
        if #available(iOS 12.0, *) {
            if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
                svgLayer.fillColor = config.darkTheme.foreground.cgColor
            } else {
                configureLightTheme()
            }
        } else {
            configureLightTheme()
        }
        
        svgLayer.fillRule = .evenOdd
        
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
        let bezier = UIBezierPath()
        
        //
        // megaphone outline; clockwise
        //
        
        // bottom right corner of megaphone exit
        bezier.move(to: CGPoint(x: 12.5297, y: 12.03))
        
        // horizontal line leftwards
        bezier.addLine(to: CGPoint(x: 9.91972, y: 12.03))
        
        // angled line up/leftwards
        bezier.addCurve(to: CGPoint(x: 9.49972, y: 11.9), controlPoint1: CGPoint(x: 9.77033, y: 12.0268), controlPoint2: CGPoint(x: 9.62483, y: 11.9817))
        
        // soft corner at top right of megaphone handle
        let topRightOuterHandleCorner = CGPoint(x: 6.43972, y: 9.79003)
        bezier.addLine(to: topRightOuterHandleCorner)
        bezier.addLine(to: CGPoint(x: 5.99965, y: 9.79003))
        
        // right edge of handle, straight downwards
        let bottomRightOuterHandleCorner = CGPoint(x: 5.99965, y: 15.31)
        bezier.addLine(to: bottomRightOuterHandleCorner)
        
        // soft corner at bottom right of handle
        bezier.addCurve(to: CGPoint(x: 5.77805, y: 15.8084), controlPoint1: CGPoint(x: 5.99, y: 15.4979), controlPoint2: CGPoint(x: 5.91104, y: 15.6754))
        bezier.addCurve(to: CGPoint(x: 5.27965, y: 16.03), controlPoint1: CGPoint(x: 5.64506, y: 15.9414), controlPoint2: CGPoint(x: 5.46748, y: 16.0204))
        
        // line to the bottom left corner of the handle
        let bottomLeftHandleCornerOuter = CGPoint(x: 1.63965, y: 16.03)
        bezier.addLine(to: bottomLeftHandleCornerOuter)
        
        // soft corner at bottom left of handle
        bezier.addCurve(to: CGPoint(x: 1.11218, y: 15.8075), controlPoint1: CGPoint(x: 1.44154, y: 16.0274), controlPoint2: CGPoint(x: 1.25228, y: 15.9476))
        bezier.addCurve(to: CGPoint(x: 0.889648, y: 15.28), controlPoint1: CGPoint(x: 0.972088, y: 15.6674), controlPoint2: CGPoint(x: 0.892238, y: 15.4781))
        
        // left vertical side of handle upwards
        let topLeftHandleOuterCorner = CGPoint(x: 0.889648, y: 9.79003)
        bezier.addLine(to: topLeftHandleOuterCorner)
        
        // soft corners to the bottom left edge of the megaphone back
        bezier.addLine(to: CGPoint(x: 0.759722, y: 9.79003))
        bezier.addCurve(to: CGPoint(x: 0.467299, y: 9.73492), controlPoint1: CGPoint(x: 0.659545, y: 9.79137), controlPoint2: CGPoint(x: 0.560114, y: 9.77264))
        bezier.addCurve(to: CGPoint(x: 0.219324, y: 9.57043), controlPoint1: CGPoint(x: 0.290166, y: 9.64127), controlPoint2: CGPoint(x: 0.374484, y: 9.6972))
        bezier.addCurve(to: CGPoint(x: 0.0548335, y: 9.32245), controlPoint1: CGPoint(x: 0.148482, y: 9.49959), controlPoint2: CGPoint(x: 0.0925509, y: 9.41527))
        bezier.addCurve(to: CGPoint(x: -0.000278464, y: 9.03003), controlPoint1: CGPoint(x: 0.0171161, y: 9.22964), controlPoint2: CGPoint(x: -0.0016233, y: 9.13021))
        
        // vertical line upwards at the megaphone back
        bezier.addLine(to: CGPoint(x: -0.000278464, y: 3.03003))
        
        bezier.addCurve(to: CGPoint(x: 0.0426121, y: 2.72526), controlPoint1: CGPoint(x: -0.00720398, y: 2.92657), controlPoint2: CGPoint(x: 0.00740032, y: 2.82279))
        bezier.addCurve(to: CGPoint(x: 0.204297, y: 2.46338), controlPoint1: CGPoint(x: 0.0778238, y: 2.62773), controlPoint2: CGPoint(x: 0.132878, y: 2.53855))
        bezier.addCurve(to: CGPoint(x: 0.45755, y: 2.28848), controlPoint1: CGPoint(x: 0.275717, y: 2.3882), controlPoint2: CGPoint(x: 0.36195, y: 2.32865))
        bezier.addCurve(to: CGPoint(x: 0.759722, y: 2.23003), controlPoint1: CGPoint(x: 0.55315, y: 2.24832), controlPoint2: CGPoint(x: 0.65604, y: 2.22842))
        
        bezier.addLine(to: CGPoint(x: 6.43972, y: 2.23003))
        
        // diagonal
        bezier.addLine(to: CGPoint(x: 9.49972, y: 0.160029))
        
        bezier.addCurve(to: CGPoint(x: 9.91972, y: 0.0300293), controlPoint1: CGPoint(x: 9.62483, y: 0.0783212), controlPoint2: CGPoint(x: 9.77033, y: 0.0332871))
        
        bezier.addLine(to: CGPoint(x: 12.5297, y: 0.0300293))
        bezier.addCurve(to: CGPoint(x: 13.0572, y: 0.252563), controlPoint1: CGPoint(x: 12.7278, y: 0.0326193), controlPoint2: CGPoint(x: 12.9171, y: 0.112468))
        bezier.addCurve(to: CGPoint(x: 13.2797, y: 0.780029), controlPoint1: CGPoint(x: 13.1973, y: 0.392658), controlPoint2: CGPoint(x: 13.2771, y: 0.581922))
        
        let topSoundExitPoint = CGPoint(x: 13.2797, y: 2.63218)
        bezier.addLine(to: topSoundExitPoint)
        bezier.addCurve(to: CGPoint(x: 14.9769, y: 3.56346), controlPoint1: CGPoint(x: 13.9175, y: 2.7737), controlPoint2: CGPoint(x: 14.5076, y: 3.09424))
        bezier.addCurve(to: CGPoint(x: 15.9903, y: 6.01005), controlPoint1: CGPoint(x: 15.6257, y: 4.21234), controlPoint2: CGPoint(x: 15.9903, y: 5.0924))
        bezier.addCurve(to: CGPoint(x: 14.9769, y: 8.45664), controlPoint1: CGPoint(x: 15.9903, y: 6.9277), controlPoint2: CGPoint(x: 15.6257, y: 7.80776))
        bezier.addCurve(to: CGPoint(x: 13.2797, y: 9.38792), controlPoint1: CGPoint(x: 14.5076, y: 8.92586), controlPoint2: CGPoint(x: 13.9175, y: 9.2464))
        
        let bottomSoundExitPoint = CGPoint(x: 13.2797, y: 11.24)
        bezier.addLine(to: bottomSoundExitPoint) // vertical line extending upwards from top of sound exiting megaphone
        bezier.addCurve(to: CGPoint(x: 13.2316, y: 11.5378), controlPoint1: CGPoint(x: 13.2837, y: 11.3415), controlPoint2: CGPoint(x: 13.2674, y: 11.4427))
        bezier.addCurve(to: CGPoint(x: 13.0715, y: 11.7934), controlPoint1: CGPoint(x: 13.1959, y: 11.6328), controlPoint2: CGPoint(x: 13.1414, y: 11.7197))
        bezier.addCurve(to: CGPoint(x: 12.8246, y: 11.9665), controlPoint1: CGPoint(x: 13.0016, y: 11.867), controlPoint2: CGPoint(x: 12.9176, y: 11.9259))
        bezier.addCurve(to: CGPoint(x: 12.5297, y: 12.03), controlPoint1: CGPoint(x: 12.5297, y: 12.03), controlPoint2: CGPoint(x: 12.6313, y: 12.0288))
        bezier.close()

        //
        // inner part of the megaphone
        //
        
        bezier.move(to: CGPoint(x: 1.51756, y: 8.29003))
        bezier.addLine(to: CGPoint(x: 1.50972, y: 8.29003))
        bezier.addLine(to: CGPoint(x: 1.50972, y: 3.73003))
        bezier.addLine(to: CGPoint(x: 6.66972, y: 3.72844))
        bezier.addCurve(to: CGPoint(x: 7.08972, y: 3.60003), controlPoint1: CGPoint(x: 6.81938, y: 3.72844), controlPoint2: CGPoint(x: 6.96533, y: 3.68326))
        bezier.addLine(to: CGPoint(x: 10.1497, y: 1.53003))
        bezier.addLine(to: CGPoint(x: 11.7797, y: 1.53003))
        bezier.addLine(to: CGPoint(x: 11.7797, y: 10.53))
        bezier.addLine(to: CGPoint(x: 10.1497, y: 10.53))
        bezier.addLine(to: CGPoint(x: 7.08972, y: 8.42003))
        bezier.addCurve(to: CGPoint(x: 6.66972, y: 8.29003), controlPoint1: CGPoint(x: 6.96533, y: 8.3368), controlPoint2: CGPoint(x: 6.81938, y: 8.29162))
        bezier.addLine(to: CGPoint(x: 1.76173, y: 8.29003))
        bezier.addCurve(to: CGPoint(x: 1.63965, y: 8.28003), controlPoint1: CGPoint(x: 1.72164, y: 8.28341), controlPoint2: CGPoint(x: 1.68082, y: 8.28003))
        bezier.addCurve(to: CGPoint(x: 1.51756, y: 8.29003), controlPoint1: CGPoint(x: 1.59848, y: 8.28003), controlPoint2: CGPoint(x: 1.55766, y: 8.28341))
        bezier.close()

        //
        // inner part of the handle; counterclockwise
        //
        
        let topRightInnerHandleCorner = CGPoint(x: 4.52965, y: 9.79003)
        let bottomRightInnerHandleCorner = CGPoint(x: 4.52965, y: 14.56)
        let bottomLeftInnerHandleCorner = CGPoint(x: 2.38965, y: 14.56)
        let topLeftHandleInnerCorner = CGPoint(x: 2.38965, y: 9.79003)
        bezier.move(to: topLeftHandleInnerCorner) // top left corner
        bezier.addLine(to: bottomLeftInnerHandleCorner) // bottom left
        bezier.addLine(to: bottomRightInnerHandleCorner) // bottom right
        bezier.addLine(to: topRightInnerHandleCorner) // top right
        bezier.addLine(to: topLeftHandleInnerCorner) // end at top left again
        bezier.close()

        //
        // inside the "sound" coming out of the megaphone
        //
        
        bezier.move(to: topSoundExitPoint)
        bezier.addLine(to: bottomSoundExitPoint)
        bezier.addCurve(to: CGPoint(x: 13.4084, y: 4.06854), controlPoint1: CGPoint(x: 13.3228, y: 4.04887), controlPoint2: CGPoint(x: 13.3658, y: 4.05799))
        bezier.addCurve(to: CGPoint(x: 14.194, y: 4.4615), controlPoint1: CGPoint(x: 13.6962, y: 4.1397), controlPoint2: CGPoint(x: 13.9645, y: 4.27393))
        bezier.addCurve(to: CGPoint(x: 14.7354, y: 5.15314), controlPoint1: CGPoint(x: 14.4235, y: 4.64908), controlPoint2: CGPoint(x: 14.6084, y: 4.88532))
        bezier.addCurve(to: CGPoint(x: 14.9283, y: 6.01005), controlPoint1: CGPoint(x: 14.8624, y: 5.42095), controlPoint2: CGPoint(x: 14.9283, y: 5.71365))
        bezier.addCurve(to: CGPoint(x: 14.7354, y: 6.86696), controlPoint1: CGPoint(x: 14.9283, y: 6.30645), controlPoint2: CGPoint(x: 14.8624, y: 6.59914))
        bezier.addCurve(to: CGPoint(x: 14.194, y: 7.55859), controlPoint1: CGPoint(x: 14.6084, y: 7.13478), controlPoint2: CGPoint(x: 14.4235, y: 7.37102))
        bezier.addCurve(to: CGPoint(x: 13.4084, y: 7.95156), controlPoint1: CGPoint(x: 13.9645, y: 7.74617), controlPoint2: CGPoint(x: 13.6962, y: 7.8804))
        bezier.addCurve(to: CGPoint(x: 13.2797, y: 7.97893), controlPoint1: CGPoint(x: 13.3658, y: 7.9621), controlPoint2: CGPoint(x: 13.3228, y: 7.97123))
        bezier.close()

        return bezier.cgPath
    }()
    //swiftlint:enable function_body_length
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
