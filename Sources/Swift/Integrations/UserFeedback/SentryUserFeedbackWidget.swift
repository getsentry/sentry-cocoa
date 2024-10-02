import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

struct SentryWidget {
    class Window: UIWindow {
        class RootViewController: UIViewController {
            lazy var button: UIButton = {
                let button = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 50))
                button.setTitle("Press Me", for: .normal)
                button.backgroundColor = .blue
                button.translatesAutoresizingMaskIntoConstraints = false
                button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
                return button
            }()
            
            let config: SentryUserFeedbackWidgetConfiguration
            
            init(config: SentryUserFeedbackWidgetConfiguration) {
                self.config = config
                super.init(nibName: nil, bundle: nil)
                                
                view.addSubview(button)
                
                var constraints = [NSLayoutConstraint]()
                if config.location.contains(.bottom) {
                    constraints.append(button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -config.layoutUIOffset.vertical))
                }
                if config.location.contains(.top) {
                    constraints.append(button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: config.layoutUIOffset.vertical))
                }
                if config.location.contains(.right) {
                    constraints.append(button.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -config.layoutUIOffset.horizontal))
                }
                if config.location.contains(.left) {
                    constraints.append(button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: config.layoutUIOffset.horizontal))
                }
                NSLayoutConstraint.activate(constraints)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            @objc func buttonPressed() {
                if config.animations {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                        self.button.alpha = 0
                    }
                } else {
                    button.isHidden = true
                }
                let formDialog = UIViewController(nibName: nil, bundle: nil)
                formDialog.view.backgroundColor = .white
                let label = UILabel(frame: .zero)
                label.text = "Hi, I'm a user feedback form!"
                formDialog.view.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                label.textAlignment = .center
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: formDialog.view.leadingAnchor),
                    label.trailingAnchor.constraint(equalTo: formDialog.view.trailingAnchor),
                    label.centerYAnchor.constraint(equalTo: formDialog.view.centerYAnchor)
                ])
                present(formDialog, animated: true)
            }
        }
        
        init(config: SentryUserFeedbackWidgetConfiguration) {
            super.init(frame: UIScreen.main.bounds)
            rootViewController = RootViewController(config: config)
            windowLevel = config.windowLevel
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
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

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
