import UIKit

protocol MovieDetailSectionViewControllerProtocol: UIViewController {
    var estimatedCellSize: CGSize { get }
    var colors: ColorArt.Colors? { get set }
    var details: MovieDetails? { get set }
    func triggerFetch(completion: @escaping (MovieDetailSectionFetchState) -> Void)
}

enum MovieDetailSectionFetchState {
    case none
    case triggered
    case hasContent
    case empty
    case failure
}

class MovieDetailSectionViewController<ItemType, CellType: UICollectionViewCell>: UICollectionViewController, MovieDetailSectionViewControllerProtocol {
    let errorHandler: ErrorHandler?

    var colors: ColorArt.Colors? {
        didSet {
            if isViewLoaded {
                updateColors()
                collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
            }
        }
    }

    var details: MovieDetails?

    private let reuseIdentifier = String(describing: CellType.self)

    private(set) lazy var estimatedCellSize: CGSize = {
        let fittingSize = CellType().systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: ceil(fittingSize.width), height: ceil(fittingSize.height))
    }()

    private var items = [ItemType]() {
        didSet {
            if isViewLoaded {
                collectionView.reloadData()
            }
        }
    }

    private var fetchState = MovieDetailSectionFetchState.none
    private var pendingFetchCompletionHandlers = [(MovieDetailSectionFetchState) -> Void]()

    init(errorHandler: ErrorHandler?) {
        self.errorHandler = errorHandler

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0.0, left: 15.0, bottom: 0.0, right: 15.0)

        super.init(collectionViewLayout: layout)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateColors()
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(CellType.self, forCellWithReuseIdentifier: reuseIdentifier)

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = estimatedCellSize
        }
    }

    // MARK: API

    func itemAtIndexPath(_ indexPath: IndexPath) -> ItemType {
        items[indexPath.item]
    }

    func triggerFetch(completion: @escaping (MovieDetailSectionFetchState) -> Void) {
        switch fetchState {
        case .none:
            pendingFetchCompletionHandlers.append(completion)
            fetchState = .triggered
            fetch { result in
                switch result {
                case let .success(items):
                    self.items = items
                    self.fetchState = items.isEmpty ? .empty : .hasContent
                case let .failure(error):
                    self.errorHandler?(error)
                    self.fetchState = .failure
                }
                for handler in self.pendingFetchCompletionHandlers {
                    handler(self.fetchState)
                }
                self.pendingFetchCompletionHandlers.removeAll()
            }
        case .hasContent, .empty, .failure:
            completion(fetchState)
        case .triggered:
            pendingFetchCompletionHandlers.append(completion)
        }
    }

    // MARK: Subclass Overrides

    func configureCell(indexPath _: IndexPath, item _: ItemType, cell _: CellType) {
        fatalError("Must be overridden by subclasses")
    }

    func fetch(completion _: @escaping (Result<[ItemType], Swift.Error>) -> Void) {
        fatalError("Must be overridden by subclasses")
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in _: UICollectionView) -> Int {
        1
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? CellType ?? CellType()
        configureCell(indexPath: indexPath, item: itemAtIndexPath(indexPath), cell: cell)
        return cell
    }

    // MARK: Private

    private func updateColors() {
        collectionView.backgroundColor = ColorUtils.colorFromCGColor(colors?.backgroundColor)
    }
}
