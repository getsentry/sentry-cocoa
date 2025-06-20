#if !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
import UIKit

public class SampleAppDebugMenu: NSObject {
    public static let shared = SampleAppDebugMenu()

    static var displayingMenu = false

    let window = {
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return Window(windowScene: scene)
            }
        }
        return Window()
    }()

    lazy var rootVC = {
        let uivc = UIViewController(nibName: nil, bundle: nil)
        uivc.view.addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: uivc.view.safeAreaLayoutGuide.leadingAnchor, constant: 25),
            button.bottomAnchor.constraint(equalTo: uivc.view.safeAreaLayoutGuide.bottomAnchor, constant: -75)
        ])

        return uivc
    }()

    lazy var button = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(displayDebugMenu), for: .touchUpInside)
        button.setTitle("SDK Debug", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        return button
    }()

    @objc public func display() {
        window.rootViewController = rootVC
        window.isHidden = false
    }

    @objc func displayDebugMenu() {
        SampleAppDebugMenu.displayingMenu = true

        let listVC = FeaturesViewController(nibName: nil, bundle: nil)
        listVC.presentationController?.delegate = self
        rootVC.present(listVC, animated: true)
    }

    class Window: UIWindow {

        @available(iOS 13.0, *)
        override init(windowScene: UIWindowScene) {
            super.init(windowScene: windowScene)
            commonInit()
        }

        init() {
            super.init(frame: UIScreen.main.bounds)
            commonInit()
        }

        func commonInit() {
            windowLevel = UIWindow.Level.alert + 1
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard !SampleAppDebugMenu.displayingMenu else {
                return super.hitTest(point, with: event)
            }

            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            guard result.isKind(of: UIButton.self) else {
                return nil
            }
            return result
        }
    }
}

extension SampleAppDebugMenu: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        rootVC.dismiss(animated: true)
        SampleAppDebugMenu.displayingMenu = false
    }
}
#endif // !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
