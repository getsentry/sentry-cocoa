import Foundation
import UIKit

class PageViewController: UIPageViewController, UIPageViewControllerDataSource {
    
    class RedViewController: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .red
        }
    }
    
    class GreenViewController: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .green
        }
    }
    
    let redViewController = RedViewController()
    let greenViewController = GreenViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = self
        setViewControllers([redViewController], direction: .forward, animated: false)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        viewController == redViewController ? greenViewController : redViewController
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        viewController == redViewController ? greenViewController : redViewController
    }
    
}
