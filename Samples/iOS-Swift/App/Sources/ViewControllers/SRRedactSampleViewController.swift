import SentrySwift
import SwiftUI
import UIKit

final class SRRedactSampleViewController: UIViewController {
    private static let animatedLabelAnimationKey = "replay-fixture-animation"

    @IBOutlet private var notRedactedView: UIView?
    @IBOutlet private var notRedactedLabel: UILabel?
    @IBOutlet private var label: UILabel?

    private let animatedLabel: UILabel = {
        let label = SplitBackgroundLabel()
        label.accessibilityIdentifier = "replay-fixture-animated-label"
        label.font = .boldSystemFont(ofSize: 18)
        label.text = "ANIMATED"
        label.textAlignment = .center
        label.textColor = .black
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Replay Masking Fixture"
        view.backgroundColor = .white
        view.subviews.forEach { $0.removeFromSuperview() }

        let grid = UIStackView(arrangedSubviews: [
            row(maskedUIKitLabel(), maskedUIKitTextField()),
            row(maskedUIKitImage(), hostedView(rootView: swiftUIText())),
            row(hostedView(rootView: swiftUIImage()), explicitlyMaskedView()),
            row(explicitlyUnmaskedView(), hostedView(rootView: explicitlyMaskedSwiftUIView())),
            row(hostedView(rootView: explicitlyUnmaskedSwiftUIView()), animatedLabel)
        ])
        grid.axis = .vertical
        grid.spacing = 16
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            grid.heightAnchor.constraint(equalToConstant: 384)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Keep a presentation layer moving to cover replay masking during active Core Animation.
        // See https://github.com/getsentry/sentry-cocoa/pull/4574.
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -8
        animation.toValue = 8
        animation.duration = 0.3
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animatedLabel.layer.add(animation, forKey: Self.animatedLabelAnimationKey)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animatedLabel.layer.removeAnimation(forKey: Self.animatedLabelAnimationKey)
    }

    private func row(_ leadingView: UIView, _ trailingView: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [leadingView, trailingView])
        row.axis = .horizontal
        row.spacing = 16
        row.distribution = .fillEqually
        return row
    }

    private func maskedUIKitLabel() -> UILabel {
        let label = SplitBackgroundLabel()
        label.accessibilityIdentifier = "replay-fixture-uikit-label"
        label.font = .boldSystemFont(ofSize: 24)
        label.text = "PRIVATE"
        label.textAlignment = .center
        label.textColor = .black
        return label
    }

    private func maskedUIKitTextField() -> UITextField {
        let textField = SplitBackgroundTextField()
        textField.accessibilityIdentifier = "replay-fixture-uikit-text-field"
        textField.borderStyle = .none
        textField.font = .boldSystemFont(ofSize: 20)
        textField.text = "PRIVATE"
        textField.textAlignment = .center
        textField.textColor = .white
        return textField
    }

    private func maskedUIKitImage() -> UIImageView {
        let imageView = UIImageView(image: splitImage())
        imageView.accessibilityIdentifier = "replay-fixture-uikit-image"
        imageView.isAccessibilityElement = true
        imageView.contentMode = .scaleToFill
        return imageView
    }

    private func swiftUIText() -> some View {
        ZStack {
            HStack(spacing: 0) {
                Color.red
                Color.blue
            }
            Text("PRIVATE")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityIdentifier("replay-fixture-swiftui-text")
        }
    }

    private func swiftUIImage() -> some View {
        Image(uiImage: splitImage())
            .resizable()
            .accessibilityIdentifier("replay-fixture-swiftui-image")
    }

    private func explicitlyMaskedSwiftUIView() -> some View {
        HStack(spacing: 0) {
            Color.black
            Color.white
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("replay-fixture-swiftui-explicit-mask")
        .sentryReplayMask()
    }

    private func explicitlyUnmaskedSwiftUIView() -> some View {
        Image(uiImage: splitImage())
            .resizable()
            .accessibilityIdentifier("replay-fixture-swiftui-explicit-unmask")
            .sentryReplayUnmask()
    }

    private func hostedView<Content: View>(rootView: Content) -> UIView {
        let container = UIView()
        let hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        return container
    }

    private func explicitlyMaskedView() -> UIView {
        let view = splitColorView(identifier: "replay-fixture-explicit-mask")
        SentrySDK.replay.maskView(view)
        return view
    }

    private func explicitlyUnmaskedView() -> UIView {
        let view = splitColorView(identifier: "replay-fixture-explicit-unmask")
        SentrySDK.replay.unmaskView(view)
        return view
    }

    private func splitColorView(identifier: String) -> UIView {
        let container = UIView()
        container.accessibilityIdentifier = identifier
        container.isAccessibilityElement = true

        let red = UIView()
        red.backgroundColor = .red
        let blue = UIView()
        blue.backgroundColor = .blue

        let colors = UIStackView(arrangedSubviews: [red, blue])
        colors.axis = .horizontal
        colors.distribution = .fillEqually
        colors.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colors)
        NSLayoutConstraint.activate([
            colors.topAnchor.constraint(equalTo: container.topAnchor),
            colors.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            colors.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            colors.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func splitImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
            UIColor.white.setFill()
            context.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
        }
    }
}

private final class SplitBackgroundView: UIView {
    private let splitLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSplitBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSplitBackground()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        splitLayer.frame = bounds
    }

    private func configureSplitBackground() {
        splitLayer.colors = [UIColor.red.cgColor, UIColor.red.cgColor, UIColor.blue.cgColor, UIColor.blue.cgColor]
        splitLayer.locations = [0, 0.5, 0.5, 1]
        splitLayer.startPoint = CGPoint(x: 0, y: 0.5)
        splitLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(splitLayer, at: 0)
    }
}

private final class SplitBackgroundLabel: UILabel {
    override func draw(_ rect: CGRect) {
        UIColor.red.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height))
        UIColor.blue.setFill()
        UIRectFill(CGRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height))
        super.draw(rect)
    }
}

private final class SplitBackgroundTextField: UITextField {
    private let splitBackground = SplitBackgroundView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSplitBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSplitBackground()
    }

    private func configureSplitBackground() {
        splitBackground.isUserInteractionEnabled = false
        splitBackground.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(splitBackground, at: 0)
        NSLayoutConstraint.activate([
            splitBackground.topAnchor.constraint(equalTo: topAnchor),
            splitBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitBackground.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
