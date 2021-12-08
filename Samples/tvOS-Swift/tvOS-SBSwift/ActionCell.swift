import Foundation
import UIKit

class ActionCell: UICollectionViewCell {
    
    var titleLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
       
    private func initialize() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 4

        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true
        
        titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        let constraints = [
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 32),
            titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -32)
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
        
    override func layoutSubviews() {
        super.layoutSubviews()
        
        UIView.animate(withDuration: 0.2) {
            self.contentView.backgroundColor = self.isFocused ? UIColor(white: 0.3, alpha: 1) : UIColor.black
            self.layer.shadowOffset = self.isFocused ? CGSize(width: 6, height: 3) : CGSize(width: 2, height: 1)
        }
    }
    
}
