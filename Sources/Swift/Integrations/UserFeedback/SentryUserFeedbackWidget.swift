import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

struct SentryWidget {
    class Window: UIWindow {
        class RootViewController: UIViewController {
            
            lazy var button = SentryUserFeedbackWidgetButtonView(action: { sender in
                if self.config.animations {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                        sender.alpha = 0
                    }
                } else {
                    sender.isHidden = true
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
                self.present(formDialog, animated: self.config.animations)
            })
            
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
            guard result.isKind(of: SentryUserFeedbackWidgetButtonView.self) else {
                return nil
            }
            return result
        }
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
