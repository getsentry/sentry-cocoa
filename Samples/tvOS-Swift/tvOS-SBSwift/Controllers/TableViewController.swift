import Foundation
import Sentry
import UIKit

class TableViewController: UITableViewController {
   
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "TableViewController"
        self.tableView.accessibilityIdentifier = "TABLE_VIEW"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CELL") ?? UITableViewCell(style: .default, reuseIdentifier: "CELL")
        cell.selectionStyle = .none
        
        let w = 1.0 - (Double(indexPath.row) / 99)
        cell.backgroundColor = UIColor(white: CGFloat(w), alpha: 1)

        return cell
    }
}
