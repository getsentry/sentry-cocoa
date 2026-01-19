#if !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
import UIKit

class EnvironmentVariableTableViewCell: UITableViewCell, UITextFieldDelegate {
    let titleLabel = UILabel(frame: .zero)

    lazy var valueField = {
        let field = UITextField(frame: .zero)
        field.delegate = self
        return field
    }()

    var override: (any SentrySDKOverride)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let stack = UIStackView(arrangedSubviews: [valueField, titleLabel])
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.matchEdgeAnchors(from: contentView)

        valueField.borderStyle = .roundedRect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if override?.overrideType == .float {
            override?.floatValue = textField.text.flatMap { Float($0) }
        } else {
            override?.stringValue = textField.text
        }
        SentrySDKWrapper.shared.startSentry()
    }
}

extension EnvironmentVariableTableViewCell: FeatureFlagCell {
    func configure(with override: any SentrySDKOverride) {
        titleLabel.text = override.rawValue

        var text: String
        if override.overrideType == .float, let value = override.floatValue {
            text = String(format: "%.2f", value)
        } else if override.overrideType == .string, let value = override.stringValue {
            text = value
        } else {
            text = "nil"
        }
        valueField.text = text

        self.override = override
    }
}
#endif // !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
