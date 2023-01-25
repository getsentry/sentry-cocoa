import Foundation
import SentrySwiftUI
import SwiftUI
import UIKit

class CustomViewController : UIViewController {

    override func loadView() {
        print("loadView")
        print("### loadView")
        super.loadView()
    }

    override func viewDidLoad() {
        let label = UILabel(frame: self.view.bounds)
        label.text = "This is UIKit"
        label.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        label.textAlignment = .center
        self.view.addSubview(label)
        print("### View Did Load")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("### Did Appear")
    }
}

struct UIKitView: UIViewControllerRepresentable {
    typealias UIViewControllerType = CustomViewController

    func makeUIViewController(context: Context) -> CustomViewController {
        print("### View Controller requested")
        return CustomViewController()
    }

    func updateUIViewController(_ uiViewController: CustomViewController, context: Context) {
    }
}

struct UIKitScreen: View {

    @StateObject var viewModel = LoremIpsumViewModel()

    var body: some View {
        SentryTracedView("UIKit in SwiftUI") {
            UIKitView()
        }.navigationTitle("UIKit in SwiftUI")
    }
}
