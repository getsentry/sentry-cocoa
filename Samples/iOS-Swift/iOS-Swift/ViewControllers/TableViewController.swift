import Foundation
import UIKit

class TableViewController: UITableViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CELL") ?? UITableViewCell(style: .default, reuseIdentifier: "CELL")
        
        let g = Double(indexPath.row) / 99
        let r = 1.0 - g
        
        cell.backgroundColor = UIColor(red: r, green: g, blue: 0, alpha: 1)
        
        return cell
    }
    
}
