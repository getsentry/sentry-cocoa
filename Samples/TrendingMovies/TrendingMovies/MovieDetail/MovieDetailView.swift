import UIKit

protocol MovieDetailViewDelegate: AnyObject {
    func movieDetailViewDidMoveToSuperview(movieDetailView: MovieDetailView)
}

class MovieDetailView: UIScrollView, UIScrollViewDelegate {
    struct Layout {
        static let backdropHeight: CGFloat = 250.0
        static let contentHorizontalInset: CGFloat = 15.0
    }

    struct DefaultColors {
        static let background = UIColor.white
        static let title = UIColor.black
        static let subtitle = UIColor.gray
        static let overview = UIColor.black
    }

    var backdropImage: UIImage? {
        didSet {
            backdropImageView.image = backdropImage
        }
    }

    var colors: ColorArt.Colors? {
        didSet {
            updateColors()
        }
    }

    override var backgroundColor: UIColor? {
        didSet {
            backdropImageView.backgroundColor = backgroundColor
            updateGradient()
        }
    }

    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }

    var originalTitle: String? {
        didSet {
            if let originalTitle = originalTitle {
                originalTitleLabel.text = "(\(originalTitle))"
                insetContentStackView.insertArrangedSubview(originalTitleLabel, at: 1)
            } else {
                originalTitleLabel.text = nil
                insetContentStackView.removeArrangedSubview(originalTitleLabel)
                originalTitleLabel.removeFromSuperview()
            }
        }
    }

    var releaseDate: Date? {
        didSet {
            updateSubtitle()
        }
    }

    var genres: [String]? {
        didSet {
            updateSubtitle()
        }
    }

    var runtimeMinutes: Int? {
        didSet {
            updateSubtitle()
        }
    }

    var overview: String? {
        didSet {
            overviewLabel.text = overview
        }
    }

    override var contentOffset: CGPoint {
        didSet {
            let yOffset = contentOffset.y
            if yOffset <= 0.0 {
                extendedBackdropHeight = abs(yOffset)
            }
        }
    }

    weak var detailViewDelegate: MovieDetailViewDelegate?

    private var backdropHeightConstraint: NSLayoutConstraint?
    private var stackViewTopConstraint: NSLayoutConstraint?
    private var extendedBackdropHeight: CGFloat = 0.0 {
        didSet {
            backdropHeightConstraint?.constant = Layout.backdropHeight + extendedBackdropHeight
            stackViewTopConstraint?.constant = -extendedBackdropHeight
        }
    }

    private lazy var backdropImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var gradientView: GradientView = {
        let gradientView = GradientView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientView.endPoint = CGPoint(x: 0.5, y: 1.0)
        return gradientView
    }()

    private lazy var backdropContainerView: UIView = {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(backdropImageView)
        containerView.addSubview(gradientView)

        NSLayoutConstraint.activate([
            backdropImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            backdropImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor),
            backdropImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            gradientView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            gradientView.heightAnchor.constraint(equalTo: backdropImageView.heightAnchor),
            gradientView.topAnchor.constraint(equalTo: backdropImageView.topAnchor)
        ])

        return containerView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        label.textColor = DefaultColors.title
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var originalTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = DefaultColors.title
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .callout)
        label.textColor = DefaultColors.subtitle
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var overviewLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = DefaultColors.overview
        label.numberOfLines = 0
        return label
    }()

    private lazy var insetContentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, overviewLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10.0
        return stackView
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [backdropContainerView, insetContentStackView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 10.0

        NSLayoutConstraint.activate([
            insetContentStackView.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -(Layout.contentHorizontalInset * 2.0))
        ])

        return stackView
    }()

    private var initialStackViewSubviewCount = 0
    private var sectionHeadingLabels = [UILabel]()

    private lazy var yearDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private lazy var runtimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.minute]
        return formatter
    }()

    convenience init() {
        self.init(frame: .zero)

        backgroundColor = DefaultColors.background
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .never

        initialStackViewSubviewCount = stackView.arrangedSubviews.count
        addSubview(stackView)

        let stackViewTopConstraint = stackView.topAnchor.constraint(equalTo: topAnchor)
        let backdropHeightConstraint = backdropContainerView.heightAnchor.constraint(equalToConstant: Layout.backdropHeight)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackViewTopConstraint,
            backdropContainerView.widthAnchor.constraint(equalTo: widthAnchor),
            backdropHeightConstraint
        ])
        self.stackViewTopConstraint = stackViewTopConstraint
        self.backdropHeightConstraint = backdropHeightConstraint
        contentInsetAdjustmentBehavior = .never
    }

    // MARK: Sections

    private(set) var numberOfSections = 0

    func insertSection(view: UIView, title: String, atIndex index: Int) {
        let label = createSectionHeadingLabel(text: title)
        sectionHeadingLabels.append(label)

        let views = [
            createSpacerView(height: 0.0),
            label,
            view
        ]
        let insertionIndex = initialStackViewSubviewCount + (index * views.count)
        precondition(insertionIndex <= stackView.arrangedSubviews.count)

        for (index, view) in views.enumerated() {
            stackView.insertArrangedSubview(view, at: index + insertionIndex)
        }

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            label.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: Layout.contentHorizontalInset),
            label.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -Layout.contentHorizontalInset)
        ])

        numberOfSections += 1
        flashScrollIndicators()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        detailViewDelegate?.movieDetailViewDidMoveToSuperview(movieDetailView: self)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let maxWidth = bounds.width - (Layout.contentHorizontalInset * 2.0)
        titleLabel.preferredMaxLayoutWidth = maxWidth
        originalTitleLabel.preferredMaxLayoutWidth = maxWidth
        overviewLabel.preferredMaxLayoutWidth = maxWidth
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        let insets = safeAreaInsets
        contentInset = UIEdgeInsets(top: 0.0, left: insets.left, bottom: insets.bottom, right: insets.right)
    }

    // MARK: Private

    private func updateColors() {
        if let colors = colors, let backgroundColor = ColorUtils.colorFromCGColor(colors.backgroundColor) {
            self.backgroundColor = backgroundColor
            let titleColor = ColorUtils.getTextColor(colors.primaryColor, isDarkBackground: colors.isDarkBackground)
            titleLabel.textColor = titleColor
            originalTitleLabel.textColor = titleColor
            subtitleLabel.textColor = ColorUtils.getTextColor(colors.detailColor, isDarkBackground: colors.isDarkBackground)
            overviewLabel.textColor = ColorUtils.getTextColor(colors.secondaryColor, isDarkBackground: colors.isDarkBackground)
            for label in sectionHeadingLabels {
                label.textColor = titleColor
            }
            indicatorStyle = colors.isDarkBackground ? .white : .black
        } else {
            backgroundColor = DefaultColors.background
            titleLabel.textColor = DefaultColors.title
            originalTitleLabel.textColor = DefaultColors.title
            subtitleLabel.textColor = DefaultColors.subtitle
            overviewLabel.textColor = DefaultColors.overview
            for label in sectionHeadingLabels {
                label.textColor = DefaultColors.title
            }
            indicatorStyle = .default
        }
    }

    private func updateGradient() {
        let backgroundColor = self.backgroundColor ?? .white
        gradientView.colors = [
            backgroundColor.withAlphaComponent(0.0),
            backgroundColor
        ]
    }

    private func updateSubtitle() {
        var subtitle = ""
        if let releaseDate = releaseDate {
            subtitle += yearDateFormatter.string(from: releaseDate)
        }
        if let genres = genres, !genres.isEmpty {
            subtitle += " | "
            subtitle += genres.prefix(2).joined(separator: ", ")
        }
        if let runtimeMinutes = runtimeMinutes {
            var components = DateComponents()
            components.minute = runtimeMinutes
            if let runtimeString = runtimeFormatter.string(from: components) {
                subtitle += " | \(runtimeString)"
            }
        }
        subtitleLabel.text = subtitle
    }

    private func createSectionHeadingLabel(text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = titleLabel.textColor
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
}

private func createSpacerView(height: CGFloat) -> UIView {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.heightAnchor.constraint(equalToConstant: height).isActive = true
    return view
}
