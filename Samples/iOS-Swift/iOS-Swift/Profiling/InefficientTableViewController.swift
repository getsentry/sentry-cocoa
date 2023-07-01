//
//  TableViewController.swift
//  main-thread-example
//
//  Created by Andrew McKnight on 6/30/23.
//

import UIKit

@available(iOS 13.0, *)
class InefficientTableViewController: AbstractTableViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        for i in 1...logFiles {
            updateProgress()
            let start = Date()

            // load the log file
            let name = "\(i)"
            let url = Bundle.main.url(forResource: name, withExtension: "log")!
            let string = try! String(contentsOf: url)

            // search the logs for symbols of interest
            let regex = try! NSRegularExpression(pattern: #"Sentry(Crash|Bread).*0x"#)
            guard let firstResult = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.count)) else {
                return
            }
            let firstRange = firstResult.range(at: 0)

            // display results in a new table cell
            let elapsed = Date().timeIntervalSince(start)
            let content = Content(title: name + ".log", string: "First match at " + String(describing: firstRange), workTime: elapsed)
            
            var snapshot = self.dataSource.snapshot()
            snapshot.appendItems([content], toSection: 0)
            self.dataSource.apply(snapshot)
        }

        for i in 1...jsonFiles {
            updateProgress()
            let start = Date()

            // load and deserialize JSON
            let name = "\(i)"
            let url = Bundle.main.url(forResource: name, withExtension: "json")!
            let data = try! Data(contentsOf: url)
            let string: String

            //swiftlint:disable todo
            // extract top-level info (TODO: search for an example of the deepest keypath. would be a good candidate for a future blog post on parallelizing intensive loopwork)
            //swiftlint:enable todo
            if let json = try! JSONSerialization.jsonObject(with: data) as? [String: Any] {
                string = "Dictionary with keys: \(json.keys.joined(separator: ", "))"
            } else {
                string = "Array"
            }

            // display results in a new table cell
            let elapsed = Date().timeIntervalSince(start)
            let content = Content(title: name + ".json", string: "Top level object: " + string, workTime: elapsed)

            var snapshot = self.dataSource.snapshot()
            snapshot.appendItems([content], toSection: 1)
            self.dataSource.apply(snapshot)
        }

        for i in 1...imageFiles {
            updateProgress()
            let start = Date()

            // load the image
            let name = "\(i)"
            let url = Bundle.main.url(forResource: name, withExtension: "PNG")!
            let data = try! Data(contentsOf: url)
            let image = UIImage(data: data)!
            let elapsed = Date().timeIntervalSince(start)

            // display results in a new table cell
            let content = Content(title: "\(name).png", image: image, workTime: elapsed)
            var snapshot = self.dataSource.snapshot()
            snapshot.appendItems([content], toSection: 2)
            self.dataSource.apply(snapshot)
        }

        showFinished()
    }
}
