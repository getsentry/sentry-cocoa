import Sentry
import UIKit

class ViewController: UICollectionViewController {

    struct Action {
        var title: String
        var callback: () -> Void
    }
    
    var actions: [Action]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.8, alpha: 1)
        self.navigationController?.navigationBar.backgroundColor = UIColor.black
        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 20, left: 10, bottom: 10, right: 10)
        layout.itemSize = CGSize(width: (UIScreen.main.bounds.width / 4) - 20, height: 200)
        layout.minimumInteritemSpacing = 20

        self.collectionView.collectionViewLayout = layout
        self.collectionView.register(ActionCell.self, forCellWithReuseIdentifier: "ActionCell")
        
        actions = [
            Action(title: "Open TableViewController", callback: openTableView),
            Action(title: "Open Nib ViewController", callback: openNibViewController),
            Action(title: "Open SplitViewController", callback: openSplitViewController)
        ]
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let result = collectionView.dequeueReusableCell(withReuseIdentifier: "ActionCell", for: indexPath) as? ActionCell ?? ActionCell()
        result.titleLabel.text = actions[indexPath.item].title
        return result
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        actions[indexPath.item].callback()
    }
        
    private func openTableView() {
        let tableVC = TableViewController()
        navigationController?.pushViewController(tableVC, animated: true)
    }
    
    private func openNibViewController() {
        let nibVC = NibViewController()
        navigationController?.pushViewController(nibVC, animated: true)
    }
    
    private func openSplitViewController() {
        let splitVC = SplitViewController(style: .doubleColumn)
        self.present(splitVC, animated: false, completion: nil)
    }
}
