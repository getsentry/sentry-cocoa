//
//  Helpers.swift
//  main-thread-example
//
//  Created by Andrew McKnight on 6/30/23.
//

import UIKit

struct Content: Hashable {
    var title: String
    var string: String?
    var image: UIImage?
    var workTime: TimeInterval

    var displayText: String {
        if let string {
            return "\(title): \(string) (\(workTime.secondsString) seconds)"
        } else {
            return "\(title) (\(workTime.secondsString) seconds)"
        }
    }
}

@available(iOS 13.0, *)
class DataSource: UITableViewDiffableDataSource<Int, Content> {
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Logfile matches"
        case 1:
            return "JSON top-level elements"
        default:
            return "Images"
        }
    }
}

extension OperationQueue {
    class var backgroundQueue: OperationQueue {
        let queue = OperationQueue()
        queue.qualityOfService = .background // higher QoS classes wound up drawing the UI ok, but not responding to touch events: couldn't scroll the table view!
        queue.maxConcurrentOperationCount = 2 // if we don't constrain this amount, we'll wind up frontloading every CPU core with a long operation, which is the logfile parsing by far; only allowing 3 to run at a time allows to complete smaller types of work like the image and json decoding so we can see updates to the table view as soon as possible
        return queue
    }
}

extension TimeInterval {
    var secondsString: String {
        NSString(format: "%.1f", self) as String
    }
}

@available(iOS 13.0, *)
class AbstractTableViewController: UITableViewController {
    var task = 0
    let logFiles = 5
    let jsonFiles = 5
    let imageFiles = 5  

    let spinner = UIActivityIndicatorView(style: .medium)
    let titleLabel = UILabel(frame: .zero)

    lazy var dataSource: UITableViewDiffableDataSource<Int, Content> = {
        return DataSource(tableView: tableView) { tableView, indexPath, itemIdentifier in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            if #available(iOS 14.0, *) {
                cell.configure(section: indexPath.section, content: itemIdentifier)
            }
            return cell
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        spinner.color = .darkGray

        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .boldSystemFont(ofSize: 30)
        view.addSubview(titleLabel)

        self.tableView.tableHeaderView = view

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),

            spinner.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -12),
            spinner.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),
            spinner.heightAnchor.constraint(equalToConstant: 30),

            view.heightAnchor.constraint(equalToConstant: 60),
            view.widthAnchor.constraint(equalTo: tableView.widthAnchor, multiplier: 1),
            view.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            view.topAnchor.constraint(equalTo: tableView.topAnchor)
        ])

        var snapshot = NSDiffableDataSourceSnapshot<Int, Content>()
        snapshot.appendSections([0, 1, 2])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func updateProgress() {
        task += 1
        titleLabel.text = "Executing \(task) of \(logFiles + jsonFiles + imageFiles)"
    }

    func showFinished() {
        spinner.stopAnimating()
        titleLabel.text = "Finished!"
        let alert = UIAlertController(title: "Finished!", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

@available(iOS 14.0, *)
class CustomTableViewCell: UITableViewCell {
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        var contentConfig = defaultContentConfiguration().updated(for: state)
        contentConfig.text = "Hello World"
        contentConfig.image = UIImage(systemName: "bell")

        var backgroundConfig = backgroundConfiguration?.updated(for: state)
        backgroundConfig?.backgroundColor = .purple

        if state.isHighlighted || state.isSelected {
            backgroundConfig?.backgroundColor = .orange
            contentConfig.textProperties.color = .red
            contentConfig.imageProperties.tintColor = .yellow
        }

        contentConfiguration = contentConfig
        backgroundConfiguration = backgroundConfig
    }
}

@available(iOS 14.0, *)
extension UITableViewCell {
    func configure(section: Int, content: Content) {
        var config = defaultContentConfiguration()
        switch section {
        case 0:
            config.text = content.displayText
        case 1:
            config.text = content.displayText
        default:
            config.text = content.displayText
            config.image = content.image
            config.imageProperties.maximumSize = CGSize(width: 50, height: 50)
        }
        contentConfiguration = config
    }
}
