import UIKit

class EnvironmentVariableTableViewCell: UITableViewCell, UITextFieldDelegate {
    let titleLabel = UILabel(frame: .zero)

    lazy var valueField = {
        let field = UITextField(frame: .zero)
        field.delegate = self
        return field
    }()

    var float: Bool = false
    var override: (any SentrySDKOverride)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let stack = UIStackView(arrangedSubviews: [valueField, titleLabel])
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.matchEdgeAnchors(from: contentView, topPad: 8, bottomPad: 8)

        valueField.borderStyle = .roundedRect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with override: any SentrySDKOverride, float: Bool) {
        titleLabel.text = override.rawValue as? String

        var text: String
        if let value = override.floatValue {
            text = String(format: "%.2f", value)
        } else if let value = override.stringValue {
            text = value
        } else {
            text = "nil"
        }
        valueField.text = text

        self.float = float
        self.override = override
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if self.float {
            override?.floatValue = textField.text.flatMap { Float($0) }
        } else {
            override?.stringValue = textField.text
        }
    }
}
