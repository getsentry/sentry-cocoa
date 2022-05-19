import UIKit

/// A container view that renders itself with rounded corners.
class RoundedCornerView: UIView {
    private let corners: UIRectCorner
    private let radius: CGFloat

    /// Constructs an instance of `RoundedCornerView`
    ///
    /// - Parameters:
    ///   - corners: The corners to round.
    ///   - radius: The radius to round the corners with.
    init(corners: UIRectCorner, radius: CGFloat) {
        self.corners = corners
        self.radius = radius

        super.init(frame: .zero)

        clipsToBounds = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = layer.mask as? CAShapeLayer ?? CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
}
