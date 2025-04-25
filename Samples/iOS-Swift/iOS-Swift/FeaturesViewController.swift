import UIKit

class FeaturesViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(LaunchArgumentTableViewCell.self, forCellReuseIdentifier: "launchArgumentCell")
        tableView.register(EnvironmentVariableTableViewCell.self, forCellReuseIdentifier: "environmentVariableCell")
        tableView.tableHeaderView = tableHeader
    }

    var tableHeader: UIView {
        let resetButton = UIButton(type: .custom)
        resetButton.setTitle("Reset Defaults", for: .normal)
        resetButton.setTitleColor(.blue, for: .normal)
        resetButton.addTarget(self, action: #selector(resetDefaults), for: .touchUpInside)

        let label = UILabel(frame: .zero)
        label.text = SentrySDKOverrides.schemaPrecedenceForEnvironmentVariables ? "Schema Precedence" : "Defaults Precedence"

        let stack = UIStackView(arrangedSubviews: [label, resetButton])
        stack.spacing = 8

        let header = UIView(frame: .zero)
        header.addSubview(stack)

        stack.matchEdgeAnchors(from: header)
        header.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        return header
    }

    @objc func resetDefaults() {
        SentrySDKOverrides.resetDefaults()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        6
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
