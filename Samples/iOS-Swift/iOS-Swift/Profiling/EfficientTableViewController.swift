import UIKit

@available(iOS 13.0, *)
class EfficientTableViewController: AbstractTableViewController {

    // set up a queue for each type of work, so each type can be done concurrently
    lazy var logQueue = OperationQueue.backgroundQueue
    lazy var jsonQueue = OperationQueue.backgroundQueue
    lazy var imageQueue = OperationQueue.backgroundQueue

    //swiftlint:disable function_body_length
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let main = DispatchQueue.main
        let finishOp = BlockOperation {
            self.showFinished()
        }

        for i in 1...logFiles {
            let op = BlockOperation {
                main.async { self.updateProgress() }

                let start = Date()
                let name = "\(i)"
                let url = Bundle.main.url(forResource: name, withExtension: "log")!
                let string = try! String(contentsOf: url)
                let regex = try! NSRegularExpression(pattern: #"Sentry(Crash|Bread)"#)
                guard let firstResult = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.count)) else {
                    return
                }
                let firstRange = firstResult.range(at: 0)
                let elapsed = Date().timeIntervalSince(start)
                let content = Content(title: name + ".log", string: "First match at " + String(describing: firstRange), workTime: elapsed)

                main.async {
                    var snapshot = self.dataSource.snapshot()
                    snapshot.appendItems([content], toSection: 0)
                    self.dataSource.apply(snapshot)
                }
            }
            finishOp.addDependency(op)
            logQueue.addOperation(op)
        }

        for i in 1...jsonFiles {
            let op = BlockOperation {
                main.async { self.updateProgress() }

                let start = Date()
                let name = "\(i)"
                let url = Bundle.main.url(forResource: name, withExtension: "json")!
                let data = try! Data(contentsOf: url)
                let string: String
                if let json = try! JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    string = "Dictionary with keys: \(json.keys.joined(separator: ", "))"
                } else {
                    string = "Array"
                }
                let elapsed = Date().timeIntervalSince(start)
                let content = Content(title: name + ".json", string: "Top level object: " + string, workTime: elapsed)

                main.async {
                    var snapshot = self.dataSource.snapshot()
                    snapshot.appendItems([content], toSection: 1)
                    self.dataSource.apply(snapshot)
                }
            }
            finishOp.addDependency(op)
            jsonQueue.addOperation(op)
        }

        if #available(iOS 15.0, *) {
            for i in 1..<imageFiles {
                let op = BlockOperation {
                    main.async { self.updateProgress() }

                    let start = Date()
                    let name = "\(i)"
                    let url = Bundle.main.url(forResource: name, withExtension: "PNG")!
                    let data = try! Data(contentsOf: url)
                    guard let image = UIImage(data: data)?.preparingForDisplay() else { return }
                    let elapsed = Date().timeIntervalSince(start)
                    let content = Content(title: "\(name).png", image: image, workTime: elapsed)

                    main.async {
                        var snapshot = self.dataSource.snapshot()
                        snapshot.appendItems([content], toSection: 2)
                        self.dataSource.apply(snapshot)
                    }
                }
                finishOp.addDependency(op)
                imageQueue.addOperation(op)
            }
        }

        OperationQueue.main.addOperation(finishOp)
    }
    //swiftlint:enable function_body_length
}
