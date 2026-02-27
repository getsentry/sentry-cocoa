import Foundation
import SentrySwiftUI
import SwiftUI
import UIKit

class CustomViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel(frame: self.view.bounds)
        label.text = "This is UIKit"
        label.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        label.textAlignment = .center
        self.view.addSubview(label)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

struct UIKitView: UIViewControllerRepresentable {
    typealias UIViewControllerType = CustomViewController

    func makeUIViewController(context: Context) -> CustomViewController {
        return CustomViewController()
    }

    func updateUIViewController(_ uiViewController: CustomViewController, context: Context) {
    }
}

struct UIKitScreen: View {
    var body: some View {
        SentryTracedView("UIKit in SwiftUI") {
            UIKitView()
        }.navigationTitle("UIKit in SwiftUI")
    }
}
