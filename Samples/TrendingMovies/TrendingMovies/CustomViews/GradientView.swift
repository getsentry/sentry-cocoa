import UIKit

/// A view that renders a linear gradient.
class GradientView: UIView {
    /// An array of colors defining the color of each gradient stop.
    var colors: [UIColor]? {
        didSet {
            gradientLayer.colors = colors?.map { $0.cgColor }
        }
    }

    /// An array of numbers defining the location of each gradient stop.
    var locations: [CGFloat]? {
        didSet {
            gradientLayer.locations = locations?.map { NSNumber(value: Double($0)) }
        }
    }

    /// The start point of the gradient in unit coordinate space.
    var startPoint: CGPoint {
        get { gradientLayer.startPoint }
        set { gradientLayer.startPoint = newValue }
    }

    /// The end point of the gradient in unit coordinate space.
    var endPoint: CGPoint {
        get { gradientLayer.endPoint }
        set { gradientLayer.endPoint = newValue }
    }

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradientLayer)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.removeAllAnimations()
    }
}
