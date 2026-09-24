#if !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
import UIKit

public class SampleAppDebugMenu: NSObject {
    public static let shared = SampleAppDebugMenu()

    lazy var button = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(displayDebugMenu), for: .touchUpInside)
        button.setTitle("SDK Debug", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        return button
    }()

    @objc public func display(in windowScene: UIWindowScene) {
        guard let window = windowScene.windows.first(where: \.isKeyWindow)
            ?? windowScene.windows.first(where: { !$0.isHidden })
            ?? windowScene.windows.first else {
            return
        }

        if button.superview !== window {
            button.removeFromSuperview()
            window.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.leadingAnchor, constant: 25),
                button.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -75)
            ])
        }
        window.bringSubviewToFront(button)
    }

    @objc func displayDebugMenu() {
        guard let presenter = SampleAppUI.presentingViewController(in: button.window) else { return }
        let listVC = FeaturesViewController(nibName: nil, bundle: nil)
        presenter.present(listVC, animated: true)
    }
}

#endif // !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
