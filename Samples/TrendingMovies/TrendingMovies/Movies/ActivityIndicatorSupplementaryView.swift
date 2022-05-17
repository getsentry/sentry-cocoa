import UIKit

class ActivityIndicatorSupplementaryView: UICollectionReusableView {
    static let reuseIdentifier = "ActivityIndicatorSupplementaryView"

    let activityIndicatorView: UIActivityIndicatorView
    override var reuseIdentifier: String? {
        ActivityIndicatorSupplementaryView.reuseIdentifier
    }

    convenience override init(frame _: CGRect) {
        self.init(style: .gray)
    }

    init(style: UIActivityIndicatorView.Style) {
        activityIndicatorView = UIActivityIndicatorView(style: style)
        super.init(frame: .zero)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicatorView.hidesWhenStopped = true
        addSubview(activityIndicatorView)

        NSLayoutConstraint.activate([
            activityIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        activityIndicatorView.stopAnimating()
    }
}
