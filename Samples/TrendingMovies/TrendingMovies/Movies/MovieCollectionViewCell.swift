import Kingfisher
import UIKit

class MovieCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "MovieCollectionViewCell"
    static let placeholderImageName = "MoviePosterPlaceholder"
    static let blurWorkQueue = DispatchQueue(label: "io.sentry.sample.trending-movies.queue.blur", qos: .utility, attributes: [.concurrent])

    private struct Layout {
        static let imageWidth: CGFloat = 170
        static let aspectRatio: CGFloat = 1.5
        static let shadowBleed: CGFloat = 20.0
        static let imageTextVerticalSpacing: CGFloat = 10.0
    }

    var widthConstraint: NSLayoutConstraint?
    var posterImage: UIImage? {
        didSet {
            print("[TrendingMovies] set poster image on cell")
            posterImageView.image = posterImage ?? UIImage(named: MovieCollectionViewCell.placeholderImageName)
            if let capturedPosterImage = posterImage, !hideShadow {
                Tracer.startTracing(interaction: "poster-blurring")
                blurPosterImage(capturedPosterImage) { blurredImage in
                    Tracer.endTracing(interaction: "poster-blurring")
                    // Image could have changed while doing the blur.
                    if self.posterImage == capturedPosterImage {
                        self.shadowImageView.image = blurredImage
                    }
                }
            } else {
                shadowImageView.image = nil
            }
        }
    }

    var hideShadow: Bool = false {
        didSet {
            shadowImageView.isHidden = hideShadow
            if hideShadow {
                shadowImageView.image = nil
            }
        }
    }

    var colors: ColorArt.Colors? {
        didSet {
            let textColor = ColorUtils.getTextColor(colors?.detailColor, isDarkBackground: colors?.isDarkBackground)
            titleLabel.textColor = textColor
            subtitleLabel.textColor = textColor
        }
    }

    var downloadTask: DownloadTask?
    var uncachedDownloadTask: URLSessionDownloadTask?
    let uncachedURLSession = URLSession(configuration: .ephemeral)

    private let posterImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: MovieCollectionViewCell.placeholderImageName)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: Layout.imageWidth),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: Layout.aspectRatio)
        ])

        return imageView
    }()

    private let shadowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: Layout.aspectRatio)
        ])

        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .headline)
        // Text placeholder so that the height isn't 0 when calculating size.
        label.text = " "
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .gray
        // Text placeholder so that the height isn't 0 when calculating size.
        label.text = " "
        return label
    }()

    private let spacerView: UIView = {
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        return spacerView
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [posterImageView, spacerView, titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 3.0
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(shadowImageView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleLabel.widthAnchor.constraint(equalTo: posterImageView.widthAnchor),
            subtitleLabel.widthAnchor.constraint(equalTo: posterImageView.widthAnchor),
            shadowImageView.widthAnchor.constraint(equalTo: posterImageView.widthAnchor),
            shadowImageView.leadingAnchor.constraint(equalTo: posterImageView.leadingAnchor),
            shadowImageView.bottomAnchor.constraint(equalTo: posterImageView.bottomAnchor, constant: Layout.shadowBleed),
            spacerView.heightAnchor.constraint(equalToConstant: Layout.imageTextVerticalSpacing - (stackView.spacing * 2.0))
        ])

        widthConstraint = contentView.widthAnchor.constraint(equalToConstant: 0.0)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        downloadTask?.cancel()
        downloadTask = nil
        posterImage = nil
    }
}

private func blurPosterImage(_ image: UIImage, completion: @escaping (UIImage?) -> Void) {
    let efficiently = ProcessInfo.processInfo.arguments.contains("--io.sentry.sample.trending-movies.launch-arg.efficient-implementation")
    func performBlur() {
        let blurredImage = ImageEffects.createBlurredBackdrop(image: image, downsamplingFactor: 1.0, blurRadius: 20.0, tintColor: nil, saturationDeltaFactor: 2.0)
        if efficiently {
            DispatchQueue.main.async {
                completion(blurredImage)
            }
        } else {
            completion(blurredImage)
        }
    }
    if efficiently {
        MovieCollectionViewCell.blurWorkQueue.async {
            performBlur()
        }
    } else {
        performBlur()
    }
}
