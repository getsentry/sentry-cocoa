import Foundation
import Sentry
import UIKit

class TableViewController: UITableViewController {
    var span: Span?
    var spanObserver: SpanObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let span = SentrySDK.span, let rootSpan = span.rootSpan() {
            self.span = span
            spanObserver = SpanObserver(span: rootSpan)
            spanObserver?.performOnFinish {
                self.assertTransaction()
            }
        }
    }
    
    func assertTransaction() {
        guard let span = self.span else {
            UIAssert.fail("Transaction was not created")
            return
        }
        
        guard let children = span.children() else {
            UIAssert.fail("Transaction has no children")
            return
        }
                
        let expectation = 5
        
        UIAssert.isEqual(children.count, expectation, "Transaction did not complete. Expecting \(expectation), got \(children.count)")
        
        spanObserver?.releaseOnFinish()
        UIAssert.hasViewControllerLifeCycle(span, "TraceTestViewController")

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
