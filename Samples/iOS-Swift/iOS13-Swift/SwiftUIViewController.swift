import Foundation
import Sentry
import SwiftUI
import UIKit

class SwiftUIViewController: UIViewController {
    
    let swiftUIView = UIHostingController(rootView: SwiftUIView())
        
    override func viewDidLoad() {
        super.viewDidLoad()
     
        addChild(swiftUIView)
        view.addSubview(swiftUIView.view)
        
        setUpConstraints()
    }
    
    private func setUpConstraints() {
        swiftUIView.view.translatesAutoresizingMaskIntoConstraints = false
        swiftUIView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        swiftUIView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        swiftUIView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        swiftUIView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
}
