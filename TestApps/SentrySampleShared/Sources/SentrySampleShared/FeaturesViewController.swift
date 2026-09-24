#if !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)

import UIKit

public class FeaturesViewController: UIViewController {
    let tableView = UITableView(frame: .zero, style: .plain)

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        tableView.register(LaunchArgumentTableViewCell.self, forCellReuseIdentifier: "launchArgumentCell")
        tableView.register(EnvironmentVariableTableViewCell.self, forCellReuseIdentifier: "environmentVariableCell")
        tableView.dataSource = self

        let stack = UIStackView(arrangedSubviews: [headerView, tableView])
        stack.axis = .vertical
        view.addSubview(stack)
        stack.matchEdgeAnchors(from: view, safeArea: true)

        view.backgroundColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    var headerView: UIView {
        let resetButton = UIButton(type: .custom)
        resetButton.setTitle("Reset Defaults", for: .normal)
        resetButton.setTitleColor(.blue, for: .normal)
        resetButton.addTarget(self, action: #selector(resetDefaults), for: .touchUpInside)

        let label = UILabel(frame: .zero)
        label.text = SentrySDKOverrides.schemaPrecedenceForEnvironmentVariables ? "Schema Precedence" : "Defaults Precedence"

        let hstack = UIStackView(arrangedSubviews: [label, resetButton])
        hstack.spacing = 8

        let dsnVC = DSNDisplayViewController(nibName: nil, bundle: nil)
        addChild(dsnVC)

        let vStack = UIStackView(arrangedSubviews: [dsnVC.view, hstack])
        vStack.axis = .vertical
        return vStack
    }

    @objc func resetDefaults() {
        SentrySDKOverrides.resetDefaults()
        SentrySDKWrapper.shared.startSentry()
        tableView.reloadData()
    }
}

extension FeaturesViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        SentrySDKOverrides.allCases.count
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        SentrySDKOverrides.allCases[section].rawValue
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        SentrySDKOverrides.allCases[section].featureFlags.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let featureType = SentrySDKOverrides.allCases[indexPath.section]
        let featureFlag = featureType.featureFlags[indexPath.row]

        let reuseIdentifier: String
        switch featureFlag.overrideType {
        case .boolean:
            reuseIdentifier = "launchArgumentCell"
        case .float, .string:
            reuseIdentifier = "environmentVariableCell"
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! FeatureFlagCell
        cell.configure(with: featureFlag)
        return cell
    }
}
#endif // !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
