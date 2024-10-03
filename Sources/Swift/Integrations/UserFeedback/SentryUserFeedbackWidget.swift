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
                svgLayer.fillColor = UIColor.white.cgColor
                svgLayer.fillRule = .evenOdd
                svgLayer.strokeColor = UIColor.black.cgColor
                
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
                    svgView.widthAnchor.constraint(equalToConstant: svgSize),
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
    let bezier1 = UIBezierPath()
    
    //M12.5297 12.03
    bezier1.move(to: CGPoint(x: 12.5297, y: 12.03))
    //H9.91972
    bezier1.addLine(to: CGPoint(x: 9.91972, y: 12.03))
    //C9.77033 12.0268 9.62483 11.9817 9.49972 11.9 x
    bezier1.addCurve(to: CGPoint(x: 9.49972, y: 11.9), controlPoint1: CGPoint(x: 9.62483, y: 11.9817), controlPoint2: CGPoint(x: 9.77033, y: 12.0268))
    //L6.43972 9.79003
    bezier1.addLine(to: CGPoint(x: 6.43972, y: 9.79003))
    //H5.99965
    bezier1.addLine(to: CGPoint(x: 5.99965, y: 15.31))
    //V15.31
    bezier1.addLine(to: CGPoint(x: 5.99965, y: 15.31))
    //C5.99 15.4979 5.91104 15.6754 5.77805 15.8084 x
    bezier1.addCurve(to: CGPoint(x: 5.77805, y: 15.8084), controlPoint1: CGPoint(x: 5.91104, y: 15.6754), controlPoint2: CGPoint(x: 5.99, y: 15.4979))
    //C5.64506 15.9414 5.46748 16.0204 5.27965 16.03 x
    bezier1.addCurve(to: CGPoint(x: 5.27965, y: 16.03), controlPoint1: CGPoint(x: 5.46748, y: 16.0204), controlPoint2: CGPoint(x: 5.64506, y: 15.9414))
    //H1.63965
    bezier1.addLine(to: CGPoint(x: 1.63965, y: 16.03))
    //C1.44154 16.0274 1.25228 15.9476 1.11218 15.8075 x
    bezier1.addCurve(to: CGPoint(x: 1.11218, y: 15.8075), controlPoint1: CGPoint(x: 1.25228, y: 15.9476), controlPoint2: CGPoint(x: 1.44154, y: 16.0274))
    //C0.972088 15.6674 0.892238 15.4781 0.889648 15.28 x
    bezier1.addCurve(to: CGPoint(x: 0.889648, y: 15.28), controlPoint1: CGPoint(x: 0.892238, y: 15.4781), controlPoint2: CGPoint(x: 0.972088, y: 15.6674))
    //V9.79003
    bezier1.addLine(to: CGPoint(x: 0.759722, y: 9.79003))
    //H0.759722
    bezier1.addLine(to: CGPoint(x: 0.759722, y: 9.79003))
    //C0.659545 9.79137 0.560114 9.77264 0.467299 9.73492 x
    bezier1.addCurve(to: CGPoint(x: 0.467299, y: 9.73492), controlPoint1: CGPoint(x: 0.560114, y: 9.77264), controlPoint2: CGPoint(x: 0.659545, y: 9.79137))
    //C0.374484 9.6972 0.290166 9.64127 0.219324 9.57043 x
    bezier1.addCurve(to: CGPoint(x: 0.219324, y: 9.57043), controlPoint1: CGPoint(x: 0.290166, y: 9.64127), controlPoint2: CGPoint(x: 0.374484, y: 9.6972))
    //C0.148482 9.49959 0.0925509 9.41527 0.0548335 9.32245 x
    bezier1.addCurve(to: CGPoint(x: 0.0548335, y: 9.32245), controlPoint1: CGPoint(x: 0.0925509, y: 9.41527), controlPoint2: CGPoint(x: 0.148482, y: 9.49959))
    //C0.0171161 9.22964 -0.0016233 9.13021 -0.000278464 9.03003 x
    bezier1.addCurve(to: CGPoint(x: -0.000278464, y: 9.03003), controlPoint1: CGPoint(x: -0.0016233, y: 9.13021), controlPoint2: CGPoint(x: 0.0171161, y: 9.22964))
    //V3.03003
    bezier1.addLine(to: CGPoint(x: 0.0426121, y: 2.72526))
    //C-0.00720398 2.92657 0.00740032 2.82279 0.0426121 2.72526
    bezier1.addCurve(to: CGPoint(x: 0.0426121, y: 2.72526), controlPoint1: CGPoint(x: -0.00720398, y: 2.92657), controlPoint2: CGPoint(x: 0.00740032, y: 2.82279))
    //C0.0778238 2.62773 0.132878 2.53855 0.204297 2.46338 x
    bezier1.addCurve(to: CGPoint(x: 0.204297, y: 2.46338), controlPoint1: CGPoint(x: 0.132878, y: 2.53855), controlPoint2: CGPoint(x: 0.0778238, y: 2.62773))
    //C0.275717 2.3882 0.36195 2.32865 0.45755 2.28848 x
    bezier1.addCurve(to: CGPoint(x: 0.45755, y: 2.28848), controlPoint1: CGPoint(x: 0.36195, y: 2.32865), controlPoint2: CGPoint(x: 0.275717, y: 2.3882))
    //C0.55315 2.24832 0.65604 2.22842 0.759722 2.23003 x
    bezier1.addCurve(to: CGPoint(x: 0.759722, y: 2.23003), controlPoint1: CGPoint(x: 0.65604, y: 2.22842), controlPoint2: CGPoint(x: 0.55315, y: 2.24832))
    //H6.43972
    bezier1.addLine(to: CGPoint(x: 6.43972, y: 0.160029))
    //L9.49972 0.160029
    bezier1.addLine(to: CGPoint(x: 9.49972, y: 0.160029))
    //C9.62483 0.0783212 9.77033 0.0332871 9.91972 0.0300293 x
    bezier1.addCurve(to: CGPoint(x: 9.91972, y: 0.0300293), controlPoint1: CGPoint(x: 9.77033, y: 0.0332871), controlPoint2: CGPoint(x: 9.62483, y: 0.0783212))
    //H12.5297
    bezier1.addLine(to: CGPoint(x: 12.5297, y: 0.03))
    //C12.7278 0.0326193 12.9171 0.112468 13.0572 0.252563 x
    bezier1.addCurve(to: CGPoint(x: 13.0572, y: 0.252563), controlPoint1: CGPoint(x: 12.9171, y: 0.112468), controlPoint2: CGPoint(x: 12.7278, y: 0.0326193))
    //C13.1973 0.392658 13.2771 0.581922 13.2797 0.780029 x
    bezier1.addCurve(to: CGPoint(x: 13.2797, y: 0.780029), controlPoint1: CGPoint(x: 13.2771, y: 0.581922), controlPoint2: CGPoint(x: 13.1973, y: 0.392658))
    //V2.63218
    bezier1.addLine(to: CGPoint(x: 13.2797, y: 2.63218))
    //C13.9175 2.7737 14.5076 3.09424 14.9769 3.56346 x
    bezier1.addCurve(to: CGPoint(x: 14.9769, y: 3.56346), controlPoint1: CGPoint(x: 14.5076, y: 3.09424), controlPoint2: CGPoint(x: 13.9175, y: 2.7737))
    //C15.6257 4.21234 15.9903 5.0924 15.9903 6.01005 x
    bezier1.addCurve(to: CGPoint(x: 15.9903, y: 6.01005), controlPoint1: CGPoint(x: 15.9903, y: 5.0924), controlPoint2: CGPoint(x: 15.6257, y: 4.21234))
    //C15.9903 6.9277 15.6257 7.80776 14.9769 8.45664 x
    bezier1.addCurve(to: CGPoint(x: 14.9769, y: 8.45664), controlPoint1: CGPoint(x: 15.6257, y: 7.80776), controlPoint2: CGPoint(x: 15.9903, y: 6.9277))
    //C14.5076 8.92586 13.9175 9.2464 13.2797 9.38792 x
    bezier1.addCurve(to: CGPoint(x: 13.2797, y: 9.38792), controlPoint1: CGPoint(x: 13.9175, y: 9.2464), controlPoint2: CGPoint(x: 14.5076, y: 8.92586))
    //V11.24
    bezier1.addLine(to: CGPoint(x: 13.2797, y: 11.24))
    //C13.2837 11.3415 13.2674 11.4427 13.2316 11.5378 x
    bezier1.addCurve(to: CGPoint(x: 13.2316, y: 11.5378), controlPoint1: CGPoint(x: 13.2674, y: 11.4427), controlPoint2: CGPoint(x: 13.2837, y: 11.3415))
    //C13.1959 11.6328 13.1414 11.7197 13.0715 11.7934 x
    bezier1.addCurve(to: CGPoint(x: 13.0715, y: 11.7934), controlPoint1: CGPoint(x: 13.1414, y: 11.7197), controlPoint2: CGPoint(x: 13.1959, y: 11.6328))
    //C13.0016 11.867 12.9176 11.9259 12.8246 11.9665 x
    bezier1.addCurve(to: CGPoint(x: 12.8246, y: 11.9665), controlPoint1: CGPoint(x: 12.9176, y: 11.9259), controlPoint2: CGPoint(x: 13.0016, y: 11.867))
    //C12.7315 12.0072 12.6313 12.0288 12.5297 12.03 x
    bezier1.addCurve(to: CGPoint(x: 12.5297, y: 12.03), controlPoint1: CGPoint(x: 12.6313, y: 12.0288), controlPoint2: CGPoint(x: 12.7315, y: 12.0072))
    //Z
    bezier1.close()

    let bezier2 = UIBezierPath()
    //M1.51756 8.29003
    bezier2.move(to: CGPoint(x: 1.51756, y: 8.29003))
    //H1.50972
    bezier2.addLine(to: CGPoint(x: 1.50972, y: 8.29003))
    //V3.73003
    bezier2.addLine(to: CGPoint(x: 1.50972, y: 3.73003))
    //H6.66972
    bezier2.addLine(to: CGPoint(x: 6.66972, y: 3.72844))
    //C6.81938 3.72844 6.96533 3.68326 7.08972 3.60003 x
    bezier2.addCurve(to: CGPoint(x: 7.08972, y: 3.60003), controlPoint1: CGPoint(x: 6.96533, y: 3.68326), controlPoint2: CGPoint(x: 6.81938, y: 3.72844))
    //L10.1497 1.53003
    bezier2.addLine(to: CGPoint(x: 10.1497, y: 1.53003))
    //H11.7797
    bezier2.addLine(to: CGPoint(x: 11.7797, y: 1.53003))
    //V10.53
    bezier2.addLine(to: CGPoint(x: 11.7797, y: 10.53))
    //H10.1497
    bezier2.addLine(to: CGPoint(x: 10.1497, y: 10.53))
    //L7.08972 8.42003
    bezier2.addLine(to: CGPoint(x: 7.08972, y: 8.42003))
    //C6.96533 8.3368 6.81938 8.29162 6.66972 8.29003 x
    bezier2.addCurve(to: CGPoint(x: 6.66972, y: 8.29003), controlPoint1: CGPoint(x: 6.81938, y: 8.29162), controlPoint2: CGPoint(x: 6.96533, y: 8.3368))
    //H1.76173
    bezier2.addLine(to: CGPoint(x: 1.76173, y: 8.29003))
    //C1.72164 8.28341 1.68082 8.28003 1.63965 8.28003 x
    bezier2.addCurve(to: CGPoint(x: 1.63965, y: 8.28003), controlPoint1: CGPoint(x: 1.68082, y: 8.28003), controlPoint2: CGPoint(x: 1.72164, y: 8.28341))
    //C1.59848 8.28003 1.55766 8.28341 1.51756 8.29003 x
    bezier2.addCurve(to: CGPoint(x: 1.51756, y: 8.29003), controlPoint1: CGPoint(x: 1.55766, y: 8.28341), controlPoint2: CGPoint(x: 1.59848, y: 8.28003))
    //Z
    bezier2.close()

    let bezier3 = UIBezierPath()
    //M2.38965 9.79003
    bezier3.move(to: CGPoint(x: 2.38965, y: 9.79003))
    //V14.56
    bezier3.addLine(to: CGPoint(x: 2.38965, y: 14.56))
    //H4.52965
    bezier3.addLine(to: CGPoint(x: 4.52965, y: 14.56))
    //V9.79003
    bezier3.addLine(to: CGPoint(x: 2.38965, y: 9.79003))
    //H2.38965
    bezier3.addLine(to: CGPoint(x: 2.38965, y: 9.79003))
    //Z
    bezier3.close()

    let bezier4 = UIBezierPath()
    //M13.2797 7.97893
    bezier4.move(to: CGPoint(x: 13.2797, y: 7.97893))
    //V4.04117
    bezier4.addLine(to: CGPoint(x: 13.2797, y: 4.04117))
    //C13.3228 4.04887 13.3658 4.05799 13.4084 4.06854 x
    bezier4.addCurve(to: CGPoint(x: 13.4084, y: 4.06854), controlPoint1: CGPoint(x: 13.3658, y: 4.05799), controlPoint2: CGPoint(x: 13.3228, y: 4.04887))
    //C13.6962 4.1397 13.9645 4.27393 14.194 4.4615 x
    bezier4.addCurve(to: CGPoint(x: 14.194, y: 4.4615), controlPoint1: CGPoint(x: 13.9645, y: 4.27393), controlPoint2: CGPoint(x: 13.6962, y: 4.1397))
    //C14.4235 4.64908 14.6084 4.88532 14.7354 5.1531 x4
    bezier4.addCurve(to: CGPoint(x: 14.7354, y: 5.15314), controlPoint1: CGPoint(x: 14.6084, y: 4.88532), controlPoint2: CGPoint(x: 14.4235, y: 4.64908))
    //C14.8624 5.42095 14.9283 5.71365 14.9283 6.01005 x
    bezier4.addCurve(to: CGPoint(x: 14.9283, y: 6.01005), controlPoint1: CGPoint(x: 14.9283, y: 5.71365), controlPoint2: CGPoint(x: 14.8624, y: 5.42095))
    //C14.9283 6.30645 14.8624 6.59914 14.7354 6.86696 x
    bezier4.addCurve(to: CGPoint(x: 14.7354, y: 6.86696), controlPoint1: CGPoint(x: 14.8624, y: 6.59914), controlPoint2: CGPoint(x: 14.9283, y: 6.30645))
    //C14.6084 7.13478 14.4235 7.37102 14.194 7.55859 x
    bezier4.addCurve(to: CGPoint(x: 14.194, y: 7.55859), controlPoint1: CGPoint(x: 14.4235, y: 7.37102), controlPoint2: CGPoint(x: 14.6084, y: 7.13478))
    //C13.9645 7.74617 13.6962 7.8804 13.4084 7.95156 x
    bezier4.addCurve(to: CGPoint(x: 13.4084, y: 7.95156), controlPoint1: CGPoint(x: 13.6962, y: 7.8804), controlPoint2: CGPoint(x: 13.9645, y: 7.74617))
    //C13.3658 7.9621 13.3228 7.97123 13.2797 7.97893 x
    bezier4.addCurve(to: CGPoint(x: 13.2797, y: 7.97893), controlPoint1: CGPoint(x: 13.3228, y: 7.97123), controlPoint2: CGPoint(x: 13.3658, y: 7.9621))
    //Z
    bezier4.close()

    bezier3.append(bezier4)
    bezier2.append(bezier3)
    bezier1.append(bezier2)

    return bezier1.cgPath
}
//swiftlint:enable function_body_length

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
