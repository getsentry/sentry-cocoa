import Foundation
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

struct SentryWidget {
    class Window: UIWindow {
        class RootViewController: UIViewController {
            lazy var button: UIView = {
                let layoutSpace: CGFloat = 8

                let svgLayer = CAShapeLayer()
                svgLayer.path = createSVGPath()
                svgLayer.fillColor = UIColor.clear.cgColor
                
                let svgSize: CGFloat = 24
                let svgView = UIView(frame: CGRect(origin: .zero, size: .init(width: svgSize, height: svgSize)))
                svgView.layer.addSublayer(svgLayer)
                
                let label = UILabel(frame: .zero)
                label.text = "Report a Bug"
                label.textColor = .black
                
                let stackView = UIStackView(arrangedSubviews: [svgView, label])
                stackView.axis = .horizontal
                stackView.spacing = layoutSpace
                stackView.translatesAutoresizingMaskIntoConstraints = false
                
                var size = label.intrinsicContentSize
                size.width += svgSize + 2 * layoutSpace
                size.height += 2 * layoutSpace
                let buttonView = UIView(frame: CGRect(origin: .zero, size: size))
                buttonView.translatesAutoresizingMaskIntoConstraints = false
                buttonView.addSubview(stackView)

                NSLayoutConstraint.activate([
                    stackView.leadingAnchor.constraint(equalTo: buttonView.leadingAnchor),
                    stackView.trailingAnchor.constraint(equalTo: buttonView.trailingAnchor),
                    stackView.topAnchor.constraint(equalTo: buttonView.topAnchor),
                    stackView.bottomAnchor.constraint(equalTo: buttonView.bottomAnchor)
                ])
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(buttonPressed))
                buttonView.addGestureRecognizer(tapGesture)
                
                return buttonView
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

//swiftlint:disable function_body_length
private func createSVGPath() -> CGPath {
    let path = UIBezierPath()
    
    path.move(to: CGPoint(x: 15.6622, y: 15))
    path.addLine(to: CGPoint(x: 12.3997, y: 14.9959))
    path.addLine(to: CGPoint(x: 12.031, y: 14.9396))
    path.addLine(to: CGPoint(x: 11.8747, y: 14.8375))
    path.addLine(to: CGPoint(x: 8.04965, y: 12.2))
    path.addLine(to: CGPoint(x: 7.49956, y: 19.1))
    path.addLine(to: CGPoint(x: 7.4875, y: 19.3348))
    path.addLine(to: CGPoint(x: 7.3888, y: 19.5568))
    path.addLine(to: CGPoint(x: 7.22256, y: 19.723))
    path.addLine(to: CGPoint(x: 7.05632, y: 19.8892))
    path.addLine(to: CGPoint(x: 6.83435, y: 19.9879))
    path.addLine(to: CGPoint(x: 6.59956, y: 20))
    path.addLine(to: CGPoint(x: 2.04956, y: 20))
    path.addLine(to: CGPoint(x: 1.80193, y: 19.9968))
    path.addLine(to: CGPoint(x: 1.56535, y: 19.8969))
    path.addLine(to: CGPoint(x: 1.39023, y: 19.7218))
    path.addLine(to: CGPoint(x: 1.21511, y: 19.5467))
    path.addLine(to: CGPoint(x: 1.1153, y: 19.3101))
    path.addLine(to: CGPoint(x: 1.11206, y: 19.0625))
    path.addLine(to: CGPoint(x: 1.11206, y: 12.2))
    path.addLine(to: CGPoint(x: 0.949652, y: 12.2017))
    path.addLine(to: CGPoint(x: 0.824431, y: 12.1783))
    path.addLine(to: CGPoint(x: 0.700142, y: 12.1311))
    path.addLine(to: CGPoint(x: 0.584123, y: 12.084))
    path.addLine(to: CGPoint(x: 0.468104, y: 12.014))
    path.addLine(to: CGPoint(x: 0.362708, y: 11.9255))
    path.addLine(to: CGPoint(x: 0.274155, y: 11.8369))
    path.addLine(to: CGPoint(x: 0.185602, y: 11.7315))
    path.addLine(to: CGPoint(x: 0.115689, y: 11.6155))
    path.addLine(to: CGPoint(x: 0.0685419, y: 11.4995))
    path.addLine(to: CGPoint(x: -0.00202913, y: 11.3752))
    path.addLine(to: CGPoint(x: -0.00034808, y: 11.25))
    path.addLine(to: CGPoint(x: -0.00900498, y: 3.75))
    path.addLine(to: CGPoint(x: 0.0092504, y: 3.49095))
    path.addLine(to: CGPoint(x: 0.0532651, y: 3.36904))
    path.addLine(to: CGPoint(x: 0.0972798, y: 3.24712))
    path.addLine(to: CGPoint(x: 0.166097, y: 3.13566))
    path.addLine(to: CGPoint(x: 0.255372, y: 3.04168))
    path.addLine(to: CGPoint(x: 0.344646, y: 2.94771))
    path.addLine(to: CGPoint(x: 0.452437, y: 2.87327))
    path.addLine(to: CGPoint(x: 0.571937, y: 2.82307))
    path.addLine(to: CGPoint(x: 0.691437, y: 2.77286))
    path.addLine(to: CGPoint(x: 0.82005, y: 2.74798))
    path.addLine(to: CGPoint(x: 0.949652, y: 2.75))
    path.addLine(to: CGPoint(x: 8.04965, y: 2.75))
    path.addLine(to: CGPoint(x: 11.8747, y: 0.1625))
    path.addLine(to: CGPoint(x: 12.031, y: 0.0603649))
    path.addLine(to: CGPoint(x: 12.2129, y: 0.00407221))
    path.addLine(to: CGPoint(x: 12.3997, y: 0))
    path.addLine(to: CGPoint(x: 15.6622, y: 0))
    path.addLine(to: CGPoint(x: 15.9098, y: 0.00323746))
    path.addLine(to: CGPoint(x: 16.1464, y: 0.103049))
    path.addLine(to: CGPoint(x: 16.3215, y: 0.278167))
    path.addLine(to: CGPoint(x: 16.4966, y: 0.453286))
    path.addLine(to: CGPoint(x: 16.5964, y: 0.689866))
    path.addLine(to: CGPoint(x: 16.5997, y: 0.9375))
    path.addLine(to: CGPoint(x: 17.3969, y: 3.42959))
    path.addLine(to: CGPoint(x: 18.1345, y: 3.83026))
    path.addLine(to: CGPoint(x: 18.7211, y: 4.41679))
    path.addLine(to: CGPoint(x: 19.5322, y: 5.22788))
    path.addLine(to: CGPoint(x: 19.9878, y: 6.32796))
    path.addLine(to: CGPoint(x: 19.9878, y: 7.47502))
    path.addLine(to: CGPoint(x: 19.9878, y: 8.62209))
    path.addLine(to: CGPoint(x: 19.5322, y: 9.72217))
    path.addLine(to: CGPoint(x: 18.7211, y: 10.5333))
    path.addLine(to: CGPoint(x: 18.1345, y: 11.1198))
    path.addLine(to: CGPoint(x: 17.3969, y: 11.5205))
    path.addLine(to: CGPoint(x: 16.5997, y: 11.6974))
    path.addLine(to: CGPoint(x: 16.6047, y: 14.0125))
    path.addLine(to: CGPoint(x: 16.6536, y: 5.02355))
    path.addLine(to: CGPoint(x: 16.7072, y: 5.03495))
    path.addLine(to: CGPoint(x: 16.7605, y: 5.04814))
    path.addLine(to: CGPoint(x: 17.1202, y: 5.13709))
    path.addLine(to: CGPoint(x: 17.4556, y: 5.30487))
    path.addLine(to: CGPoint(x: 17.7425, y: 5.53934))
    path.addLine(to: CGPoint(x: 18.0293, y: 5.77381))
    path.addLine(to: CGPoint(x: 18.2605, y: 6.06912))
    path.addLine(to: CGPoint(x: 18.4192, y: 6.40389))
    path.addLine(to: CGPoint(x: 18.578, y: 6.73866))
    path.addLine(to: CGPoint(x: 18.6603, y: 7.10452))
    path.addLine(to: CGPoint(x: 18.6603, y: 7.47502))
    path.addLine(to: CGPoint(x: 18.6603, y: 7.84552))
    path.addLine(to: CGPoint(x: 18.578, y: 8.21139))
    path.addLine(to: CGPoint(x: 18.4192, y: 8.54616))
    path.addLine(to: CGPoint(x: 18.2605, y: 8.88093))
    path.addLine(to: CGPoint(x: 18.0293, y: 9.17624))
    path.addLine(to: CGPoint(x: 17.7425, y: 9.41071))
    path.addLine(to: CGPoint(x: 17.4556, y: 9.64518))
    path.addLine(to: CGPoint(x: 17.1202, y: 9.81296))
    path.addLine(to: CGPoint(x: 16.7605, y: 9.90191))
    path.addLine(to: CGPoint(x: 16.7072, y: 9.91509))
    path.addLine(to: CGPoint(x: 16.6536, y: 9.9265))
    path.addLine(to: CGPoint(x: 16.5997, y: 9.93612))
    
    path.close()

    return path.cgPath
}
//swiftlint:enable function_body_length

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
