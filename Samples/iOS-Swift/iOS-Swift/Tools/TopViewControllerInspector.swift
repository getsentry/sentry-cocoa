import Foundation
import UIKit

class TopViewControllerInspector: UIView {
    
    static var shared: TopViewControllerInspector?
    
    private var btn: UIButton!
    private var lbl: UILabel!
    private var sentryUIApplication = SentryUIApplication()
    
    private init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 360, height: 360))
        
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        initialize()
    }
    
    private func initialize() {
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.autoresizingMask = []
        
        btn = UIButton(type: .custom)
        btn.accessibilityIdentifier = "BTN_TOPVC"
        btn.setTitle("Top VC Name", for: .normal)
        btn.backgroundColor = .blue
        btn.tintColor = .white
        btn.layer.cornerRadius = 10
        btn.layer.masksToBounds = true
        btn.addTarget(self, action: #selector(getTopVC), for: .touchUpInside)
        addSubview(btn)
        
        lbl = UILabel()
        lbl.numberOfLines = 0
        lbl.accessibilityIdentifier = "LBL_TOPVC"
        lbl.backgroundColor = .white
        lbl.layer.cornerRadius = 10
        lbl.layer.masksToBounds = true
        
        addSubview(lbl)
        
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.4
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 2
    }
    
    @objc
    private func getTopVC() {
        let names = sentryUIApplication.relevantViewControllersNames()
        lbl.text = names?.joined(separator: ", ")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        btn.frame.contains(point) ? btn : nil
    }
    
    override func layoutSubviews() {
        let screenBounds = UIScreen.main.bounds
        
        btn.frame = CGRect(x: screenBounds.width - 160, y: screenBounds.height - 160, width: 140, height: 44)
        lbl.frame = CGRect(x: 20, y: btn.frame.origin.y, width: screenBounds.width - 200, height: 44)
    }
    
    func bringToFront() {
        superview?.bringSubviewToFront(self)
    }
    
    static func show() {
        if shared == nil {
            shared = TopViewControllerInspector()
        }
        
        guard let window = (UIApplication.shared.delegate as? AppDelegate)?.window, let shared else { return }
        shared.frame = window.bounds
        
        window.addSubview(shared)
    }
}
