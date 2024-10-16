import UIKit

class SentryUserFeedbackWidgetButtonView: UIView {
    // MARK: Measurements
    
    let padding: CGFloat = 16
    let spacing: CGFloat = 8
    let svgSize: CGFloat = 16
    
    lazy var sizeWithoutLabel = CGSize(width: svgSize * config.scaleFactor + 2 * padding, height: svgSize * config.scaleFactor + 2 * padding)
    
    // MARK: Properties
    
    lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(buttonPressed))
    let action: (SentryUserFeedbackWidgetButtonView) -> Void
    let config: SentryUserFeedbackConfiguration
    lazy var megaphone = SentryUserFeedbackWidgetButtonMegaphoneIconView(config: config)
    
    // MARK: Initialization
    
    //swiftlint:disable function_body_length
    init(config: SentryUserFeedbackConfiguration, action: @escaping (SentryUserFeedbackWidgetButtonView) -> Void) {
        self.action = action
        self.config = config
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        var constraints = [NSLayoutConstraint]()
        
#if DEBUG
            precondition(config.widgetConfig.showIcon || config.widgetConfig.labelText != nil)
#endif // DEBUG
        
        if config.widgetConfig.showIcon {
            constraints.append(contentsOf: [
                megaphone.heightAnchor.constraint(equalToConstant: svgSize),
                megaphone.widthAnchor.constraint(equalTo: megaphone.heightAnchor),
                megaphone.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding)
            ])
        }
        
        if let label = label {
            
            let lozengeLayer = lozengeLayer(size: label.intrinsicContentSize)
            layer.addSublayer(lozengeLayer)
            addSubview(label)
            
            if config.widgetConfig.showIcon {
                addSubview(megaphone)
                constraints.append(contentsOf: [
                    label.leadingAnchor.constraint(equalTo: megaphone.trailingAnchor, constant: spacing * config.scaleFactor),
                    megaphone.centerYAnchor.constraint(equalTo: label.firstBaselineAnchor, constant: -config.textEffectiveHeightCenter)
                ])
            } else {
                constraints.append(contentsOf: [
                    label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding)
                ])
            }
            constraints.append(contentsOf: [
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
                label.topAnchor.constraint(equalTo: topAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else if config.widgetConfig.showIcon {
            let lozenge = lozengeLayer(size: sizeWithoutLabel)
            layer.addSublayer(lozenge)
            addSubview(megaphone)
            constraints.append(contentsOf: [
                megaphone.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
                megaphone.topAnchor.constraint(equalTo: topAnchor, constant: padding),
                megaphone.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
            ])
        } else {
            SentryLog.warning("User Feedback widget attempted to be displayed with neither text label or icon.")
        }
        
        NSLayoutConstraint.activate(constraints)
        
        addGestureRecognizer(tapGesture)
    }
    //swiftlint:enable function_body_length
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Actions
    
    @objc func buttonPressed() {
        self.action(self)
    }
    
    // MARK: UI Elements
    
    lazy var label: UILabel? = {
        guard let text = config.widgetConfig.labelText else {
            return nil
        }
        
        let label = UILabel(frame: .zero)

#if DEBUG
        precondition(!text.isEmpty)
#endif // DEBUG
        
        if text.isEmpty {
            SentryLog.warning("Attempted to show widget button with empty text label. If you don't want to show text, set `SentryUserFeedbackWidgetConfiguration.labelText` to `nil`.")
        }
        
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false

        func configureLightTheme() {
            label.textColor = config.theme.foreground
        }
        if #available(iOS 12.0, *) {
            if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
                label.textColor = config.darkTheme.foreground
            } else {
                configureLightTheme()
            }
        } else {
            configureLightTheme()
        }
        
        label.font = config.theme.font
        
        return label
    }()
    
    func lozengeLayer(size: CGSize) -> CAShapeLayer {
        var finalSize = size
        
        let hasText = config.widgetConfig.labelText != nil
        let scaledLeftPadding = (padding * config.scaleFactor) / 2
        let scaledIconSize = svgSize * config.scaleFactor
        let scaledSpacing = spacing
        if hasText {
            let iconWidthAdditions = config.widgetConfig.showIcon ? scaledLeftPadding + scaledIconSize + scaledSpacing : padding
            finalSize.width += iconWidthAdditions + padding
            finalSize.height = 2 * (config.theme.font.ascender - config.textEffectiveHeightCenter) + 2 * padding * config.paddingScaleFactor
        }
        
        let radius: CGFloat = finalSize.height / 2

        let lozengeShape = UIBezierPath()
        lozengeShape.move(to: .init(x: radius, y: 0))
        lozengeShape.addLine(to: .init(x: finalSize.width - radius, y: 0))
        lozengeShape.addArc(withCenter: .init(x: finalSize.width - radius, y: radius), radius: radius, startAngle: 3 * .pi / 2, endAngle: .pi / 2, clockwise: true)
        lozengeShape.addLine(to: .init(x: radius, y: finalSize.height))
        lozengeShape.addArc(withCenter: .init(x: radius, y: radius), radius: radius, startAngle: .pi / 2, endAngle: 3 * .pi / 2, clockwise: true)
        lozengeShape.close()
        
        let lozengeLayer = CAShapeLayer()
        lozengeLayer.path = lozengeShape.cgPath
        
        func configureLightTheme() {
            lozengeLayer.fillColor = config.theme.background.cgColor
            lozengeLayer.strokeColor = config.theme.outlineColor.cgColor
        }
        if #available(iOS 12.0, *) {
            if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
                lozengeLayer.fillColor = config.darkTheme.background.cgColor
                lozengeLayer.strokeColor = config.darkTheme.outlineColor.cgColor
            } else {
                configureLightTheme()
            }
        } else {
            configureLightTheme()
        }
        
        let iconSizeDifference = (scaledIconSize - svgSize) / 2
        if hasText {
            let paddingDifference = (scaledLeftPadding - padding) / 2
            let spacingDifference = scaledSpacing - spacing
            let increasedIconLeftPadAmountDueToScaling: CGFloat = config.widgetConfig.showIcon ? SentryLocale.isRightToLeftLanguage() ? paddingDifference : paddingDifference + iconSizeDifference + spacingDifference : 0
            lozengeLayer.transform = CATransform3DTranslate(lozengeLayer.transform, -increasedIconLeftPadAmountDueToScaling, -padding * config.paddingScaleFactor, 0)
        } else {
            lozengeLayer.transform = CATransform3DTranslate(lozengeLayer.transform, -iconSizeDifference, -iconSizeDifference, 0)
        }
        
        return lozengeLayer
    }
}
