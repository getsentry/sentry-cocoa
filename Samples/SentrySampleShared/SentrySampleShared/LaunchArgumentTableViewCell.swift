import UIKit

class LaunchArgumentTableViewCell: UITableViewCell {
    let titleLabel = UILabel(frame: .zero)
    lazy var flagSwitch = {
        let flagSwitch = UISwitch(frame: .zero)
        flagSwitch.addTarget(self, action: #selector(toggleFlag), for: .valueChanged)
        return flagSwitch
    }()
    var override: (any SentrySDKOverride)?

    @objc func toggleFlag() {
        override?.boolValue = flagSwitch.isOn
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let stack = UIStackView(arrangedSubviews: [flagSwitch, titleLabel])
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.matchEdgeAnchors(from: contentView, topPad: 8, bottomPad: 8)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with override: any SentrySDKOverride) {
        titleLabel.text = override.rawValue as? String
        flagSwitch.isOn = override.boolValue
        self.override = override
    }
}
