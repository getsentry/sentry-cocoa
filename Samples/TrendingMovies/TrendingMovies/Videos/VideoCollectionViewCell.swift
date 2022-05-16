import Kingfisher
import UIKit

class VideoCollectionViewCell: UICollectionViewCell {
    static let placeholderImageName = "VideoPlaceholder"

    private struct Layout {
        static let thumbnailWidth: CGFloat = 300.0
        static let aspectRatio: CGFloat = 16.0 / 9.0
        static let titlePadding: CGFloat = 10.0
    }

    var thumbnailImage: UIImage? {
        didSet {
            thumbnailImageView.image = thumbnailImage ?? UIImage(named: VideoCollectionViewCell.placeholderImageName)
        }
    }

    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }

    var downloadTask: DownloadTask?

    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.image = UIImage(named: VideoCollectionViewCell.placeholderImageName)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: Layout.thumbnailWidth),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: Layout.aspectRatio)
        ])

        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .callout)
        // Text placeholder so that the height isn't 0 when calculating size.
        label.text = " "
        return label
    }()

    private lazy var titleContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear

        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)

        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        vibrancyView.contentView.addSubview(titleLabel)
        blurView.contentView.addSubview(vibrancyView)

        NSLayoutConstraint.activate([
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
            blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
            vibrancyView.widthAnchor.constraint(equalTo: blurView.contentView.widthAnchor),
            vibrancyView.heightAnchor.constraint(equalTo: blurView.contentView.heightAnchor),
            titleLabel.topAnchor.constraint(equalTo: vibrancyView.contentView.topAnchor, constant: Layout.titlePadding),
            titleLabel.bottomAnchor.constraint(equalTo: vibrancyView.contentView.bottomAnchor, constant: -Layout.titlePadding),
            titleLabel.centerXAnchor.constraint(equalTo: vibrancyView.contentView.centerXAnchor)
        ])

        return view
    }()

    private lazy var roundedCornerView: RoundedCornerView = {
        let view = RoundedCornerView(corners: [.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 5.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thumbnailImageView)
        view.addSubview(titleContainerView)

        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            thumbnailImageView.topAnchor.constraint(equalTo: view.topAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            titleContainerView.widthAnchor.constraint(equalTo: thumbnailImageView.widthAnchor),
            titleContainerView.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor)
        ])

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(roundedCornerView)

        NSLayoutConstraint.activate([
            roundedCornerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            roundedCornerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            roundedCornerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            roundedCornerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).withPriority(.defaultHigh)
        ])
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.preferredMaxLayoutWidth = bounds.width - (Layout.titlePadding * 2.0)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        downloadTask?.cancel()
        downloadTask = nil
        thumbnailImage = nil
    }
}
