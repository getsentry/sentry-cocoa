import UIKit

class MovieDetailBarBackgroundView: UIView {
    private let visualEffectView: UIVisualEffectView = {
        let visualEffectView = UIVisualEffectView(effect: nil)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        return visualEffectView
    }()

    var isDarkBackground: Bool = false {
        didSet { updateEffect() }
    }

    var isVisualEffectHidden: Bool = true {
        didSet { updateEffect() }
    }

    override init(frame _: CGRect) {
        super.init(frame: .zero)
        backgroundColor = .clear

        addSubview(visualEffectView)
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateEffect() {
        visualEffectView.effect = isVisualEffectHidden
            ? nil
            : UIBlurEffect(style: isDarkBackground ? .dark : .light)
    }
}
