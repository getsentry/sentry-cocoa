import Foundation
import Sentry
import UIKit

class SentryTransactionView: UIScrollView {
    
    var span: Span?
    
    var labelChildren: UILabel!
    var labelContent: [UILabel] = []
    
    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    private func initialize() {
        labelChildren = UILabel()
        addSubview(labelChildren)
        clipsToBounds = true
        
        refresh()
    }
    
    func refresh() {
        //Schedule the refresh to be done at the end of the life cycle
        //This way the transaction may be finished
        
        DispatchQueue.main.async {
            self.renderInfo()
        }
    }
    
    private func newLabel(_ text: String) {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = text
        
        addSubview(label)
        labelContent.append(label)
    }
    
    private func renderInfo() {
        guard let localSpan: Span = span else { return }
                
        labelContent.forEach { $0.removeFromSuperview() }
        labelContent.removeAll()
            
        newLabel("Root Span")
        newLabel("isFinished: \(localSpan.isFinished)")
        
        addSpanData(localSpan)
        newLabel(" ")
        
        var i = 1
        if let children = localSpan.children() {
            labelChildren.text = "children: \(children.count)"
            
            for span in children {
            
                newLabel("Span \(i)")
                newLabel("isFinished: \(span.isFinished)")
                addSpanData(span)
                newLabel(" ")
                i += 1
            }
        }
    }
    
    private func addSpanData(_ span: Span) {
        let data = span.serialize()
        data.forEach { keyvalue in
            newLabel("\(keyvalue.key): \(keyvalue.value)")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        labelChildren.frame = CGRect(x: 0, y: 0, width: frame.width, height: 20)
        
        var y = 30.0
        for label in labelContent {
            let size = label.sizeThatFits(CGSize(width: frame.width, height: 1_000))
            label.frame = CGRect(x: 0.0, y: y, width: frame.width, height: size.height)
            y += size.height + 3
        }
        
        self.contentSize = CGSize(width: frame.width, height: y)
    }
}
