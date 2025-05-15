#if !os(macOS) && !os(tvOS) && !os(watchOS)
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
        tableView.reloadData()
    }
}

extension FeaturesViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        6
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Special"
        } else if section == 1 {
            return "Performance"
        } else if section == 2 {
            return "Tracing"
        } else if section == 3 {
            return "Profiling"
        } else if section == 4 {
            return "Feedback"
        } else if section == 5 {
            return "Other"
        }
        return nil
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return SentrySDKOverrides.Special.allCases.count
        } else if section == 1 {
            return SentrySDKOverrides.Performance.allCases.count
        } else if section == 2 {
            return SentrySDKOverrides.Tracing.allCases.count
        } else if section == 3 {
            return SentrySDKOverrides.Profiling.allCases.count
        } else if section == 4 {
            return SentrySDKOverrides.Feedback.allCases.count
        } else if section == 5 {
            return SentrySDKOverrides.Other.allCases.count
        }
        return 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 2 {
            if SentrySDKOverrides.Tracing.boolValues.contains(SentrySDKOverrides.Tracing.allCases[indexPath.row]) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "launchArgumentCell", for: indexPath) as! LaunchArgumentTableViewCell
                cell.configure(with: SentrySDKOverrides.Tracing.allCases[indexPath.row])
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "environmentVariableCell", for: indexPath) as! EnvironmentVariableTableViewCell
                cell.configure(with: SentrySDKOverrides.Tracing.allCases[indexPath.row], float: true)
                return cell
            }
        } else if indexPath.section == 3 {
            if SentrySDKOverrides.Profiling.boolValues.contains(SentrySDKOverrides.Profiling.allCases[indexPath.row]) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "launchArgumentCell", for: indexPath) as! LaunchArgumentTableViewCell
                cell.configure(with: SentrySDKOverrides.Profiling.allCases[indexPath.row])
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "environmentVariableCell", for: indexPath) as! EnvironmentVariableTableViewCell
                cell.configure(with: SentrySDKOverrides.Profiling.allCases[indexPath.row], float: true)
                return cell
            }
        } else if indexPath.section == 5 {
            if SentrySDKOverrides.Other.boolValues.contains(SentrySDKOverrides.Other.allCases[indexPath.row]) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "launchArgumentCell", for: indexPath) as! LaunchArgumentTableViewCell
                cell.configure(with: SentrySDKOverrides.Other.allCases[indexPath.row])
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "environmentVariableCell", for: indexPath) as! EnvironmentVariableTableViewCell
                cell.configure(with: SentrySDKOverrides.Other.allCases[indexPath.row], float: false)
                return cell
            }
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "launchArgumentCell", for: indexPath) as! LaunchArgumentTableViewCell
        if indexPath.section == 0 {
            cell.configure(with: SentrySDKOverrides.Special.allCases[indexPath.row])
        } else if indexPath.section == 1 {
            cell.configure(with: SentrySDKOverrides.Performance.allCases[indexPath.row])
        } else if indexPath.section == 4 {
            cell.configure(with: SentrySDKOverrides.Feedback.allCases[indexPath.row])
        }
        return cell
    }
}
#endif // !os(macOS) && !os(tvOS) && !os(watchOS)
