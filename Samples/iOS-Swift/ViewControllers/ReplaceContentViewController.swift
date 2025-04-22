import UIKit

class ReplaceContentViewController: UIViewController {

    @IBOutlet var containerView: UIView!
    private var currentChild: UIViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add the initial child controller
        let childVC = LoadCountReportingViewController(color: UIColor.systemBlue)
        self.addChild(childVC)
        childVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        childVC.view.frame = containerView.bounds
        containerView.addSubview(childVC.view)
        childVC.didMove(toParent: self)

        currentChild = childVC
    }
    
    @IBAction func tappedReplaceContent(_ sender: Any) {
        swapChild()
    }

    private func swapChild() {
        let oldChild = currentChild!
        let newChild = LoadCountReportingViewController(color: .systemPurple)

        self.addChild(newChild)
        oldChild.willMove(toParent: nil)

        self.transition(from: oldChild,
                        to: newChild,
                        duration: 0.15,
                        options: .transitionCrossDissolve,
                        animations: {
            newChild.view.frame = self.containerView.bounds
        },
                        completion: { (_) in
            self.currentChild = newChild
            newChild.didMove(toParent: self)
            oldChild.removeFromParent()
        })
    }

}

// We're using this to test some code related to child view controllers.
// The code has different behavior depending on whether the child
// controller is a container view controller, so this needs to be a
// container controller.
private class LoadCountReportingViewController: UISplitViewController {
    init(color: UIColor) {
        self.color = color
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("This controller does not support XIB or Storyboard initialization")
    }

    let color: UIColor
    var loadCountLabel: UILabel?
    private var loadCount: Int = 0

    // swiftlint:disable prohibited_super_call
    override func loadView() {
        super.loadView()
        
        loadCount += 1
    }
    // swiftlint:enable prohibited_super_call

    override func viewDidLoad() {
        super.viewDidLoad()

        if loadCountLabel == nil {
            loadCountLabel = UILabel()
            loadCountLabel!.accessibilityIdentifier = "LBL_LOAD_COUNT"
            loadCountLabel!.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(loadCountLabel!)
            loadCountLabel!.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            loadCountLabel!.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        }

        loadCountLabel!.text = "loadView() called \(loadCount) times"

        self.view.backgroundColor = self.color
    }

}
