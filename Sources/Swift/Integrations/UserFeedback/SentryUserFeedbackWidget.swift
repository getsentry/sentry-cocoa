//swiftlint:disable todo

import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

var displayingForm = false

protocol SentryUserFeedbackWidgetDelegate: NSObjectProtocol {
    func capture(feedback: SentryFeedback)
}

@available(iOS 13.0, *)
struct SentryUserFeedbackWidget {
    class Window: UIWindow {
        class RootViewController: UIViewController, SentryUserFeedbackFormDelegate, UIAdaptivePresentationControllerDelegate {
            let defaultWidgetSpacing: CGFloat = 8
            
            lazy var button = SentryUserFeedbackWidgetButtonView(config: config, action: { _ in
                self.setWidget(visible: false)
                let form = SentryUserFeedbackForm(config: self.config, delegate: self)
                form.presentationController?.delegate = self
                self.present(form, animated: self.config.animations)
            })
            
            let config: SentryUserFeedbackConfiguration
            
            weak var delegate: (any SentryUserFeedbackWidgetDelegate)?
            
            init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackWidgetDelegate) {
                self.config = config
                self.delegate = delegate
                super.init(nibName: nil, bundle: nil)
                view.addSubview(button)
                
                var constraints = [NSLayoutConstraint]()
                if config.widgetConfig.location.contains(.bottom) {
                    constraints.append(button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -config.widgetConfig.layoutUIOffset.vertical))
                }
                if config.widgetConfig.location.contains(.top) {
                    constraints.append(button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: config.widgetConfig.layoutUIOffset.vertical))
                }
                if config.widgetConfig.location.contains(.trailing) {
                    constraints.append(button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -config.widgetConfig.layoutUIOffset.horizontal))
                }
                if config.widgetConfig.location.contains(.leading) {
                    constraints.append(button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: config.widgetConfig.layoutUIOffset.horizontal))
                }
                NSLayoutConstraint.activate(constraints)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func viewDidLayoutSubviews() {
                super.viewDidLayoutSubviews()
                button.updateAccessibilityFrame()
            }
            
            // MARK: Helpers
            
            func setWidget(visible: Bool) {
                if config.animations {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                        self.button.alpha = visible ? 1 : 0
                    }
                } else {
                    button.isHidden = !visible
                }
                
                displayingForm = !visible
            }
            
            func closeForm() {
                setWidget(visible: true)
                dismiss(animated: config.animations)
            }
            
            // MARK: SentryUserFeedbackFormDelegate
            
            func finished(with feedback: SentryFeedback?) {
                closeForm()
                
                if let feedback = feedback {
                    delegate?.capture(feedback: feedback)
                }
            }
            
            // MARK: UIAdaptivePresentationControllerDelegate
            
            func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
                setWidget(visible: true)
            }
        }
        
        init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackWidgetDelegate) {
            super.init(frame: UIScreen.main.bounds)
            rootViewController = RootViewController(config: config, delegate: delegate)
            windowLevel = config.widgetConfig.windowLevel
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard !displayingForm else {
                return super.hitTest(point, with: event)
            }
            
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

#endif // os(iOS) && !SENTRY_NO_UIKIT

//swiftlint:enable todo
