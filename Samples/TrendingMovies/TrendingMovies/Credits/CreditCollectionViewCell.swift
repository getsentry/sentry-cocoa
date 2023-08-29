import Kingfisher
import UIKit

class CreditCollectionViewCell: UICollectionViewCell {
    static let placeholderImageName = "PersonPlaceholder"
    static let profileImageSize: CGFloat = 120.0

    var downloadTask: DownloadTask?

    var colors: ColorArt.Colors? {
        didSet {
            let textColor = ColorUtils.getTextColor(colors?.detailColor, isDarkBackground: colors?.isDarkBackground)
            nameLabel.textColor = textColor
            roleLabel.textColor = textColor
        }
    }

    var profileImage: UIImage? {
        didSet {
            if let profileImage = profileImage {
                profileImageView.image = profileImage
            } else {
                profileImageView.image = UIImage(named: CreditCollectionViewCell.placeholderImageName)
            }
        }
    }

    var name: String? {
        didSet {
            nameLabel.text = name
        }
    }

    var role: String? {
        didSet {
            roleLabel.text = role
        }
    }

    private lazy var profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = CreditCollectionViewCell.profileImageSize / 2.0
        imageView.clipsToBounds = true
        imageView.image = UIImage(named: CreditCollectionViewCell.placeholderImageName)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: CreditCollectionViewCell.profileImageSize),
            imageView.heightAnchor.constraint(equalToConstant: CreditCollectionViewCell.profileImageSize)
        ])

        return imageView
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .headline)
        // Text placeholder so that the height isn't 0 when calculating size.
        label.text = " "
        return label
    }()

    private lazy var roleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .footnote)
        // Text placeholder so that the height isn't 0 when calculating size.
        label.text = " "
        return label
    }()

    private lazy var stackView: UIStackView = {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 4.0).isActive = true

        let stackView = UIStackView(arrangedSubviews: [profileImageView, spacer, nameLabel, roleLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 3.0
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            stackView.heightAnchor.constraint(equalTo: contentView.heightAnchor),
            nameLabel.widthAnchor.constraint(equalTo: profileImageView.widthAnchor),
            roleLabel.widthAnchor.constraint(equalTo: profileImageView.widthAnchor)
        ])
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        downloadTask?.cancel()
        downloadTask = nil
        profileImage = nil
    }
}
