import CoreData
import Foundation
import Sentry
import UIKit

class CoreDataViewController: UITableViewController {
    
    var people = [Person]()
    
    init() {
        super.init(style: .plain)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: Core Data
    
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count - 1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel? = {
        guard let modelURL = Bundle.main.url(forResource: "SentryData", withExtension: "momd") else { return nil }
        return NSManagedObjectModel(contentsOf: modelURL)
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        guard let managedObjectModel = managedObjectModel else {
            return nil
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            //log error
            abort()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        return managedObjectContext
    }()
    
    func getEntity<T: NSManagedObject>() -> T {
        guard let entityDescription = NSEntityDescription.entity(forEntityName: NSStringFromClass(T.self), in: managedObjectContext) else {
            fatalError("Core Data entity name doesn't match.")
        }
        let obj = T(entity: entityDescription, insertInto: managedObjectContext)
        return obj
    }
    
    func saveContext () {
        // iOS 9.0 and below - however you were previously handling it
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    // MARK: Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return people.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CELL") ?? {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "CELL")
            cell.selectionStyle = .none
            return cell
        }()
        
        cell.textLabel?.text = people[indexPath.row].name
        cell.detailTextLabel?.text = people[indexPath.row].job
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle != .delete {
            return
        }
        
        managedObjectContext.delete(people[indexPath.row])
        
        people.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    
    // MARK: View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fetchRequest = NSFetchRequest<Person>(entityName: "Person")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            people = try managedObjectContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(requestNewPerson(_:)))
    }
    
    @objc
    private func requestNewPerson(_ source: Any?) {
        let alert = UIAlertController(title: "New Person", message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.returnKeyType = .next
            $0.placeholder = "Name"
        }
        alert.addTextField {
            $0.returnKeyType = .done
            $0.placeholder = "Job"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let tf1 = alert.textFields?[0], let tf2 = alert.textFields?[1], let name = tf1.text, let job = tf2.text {
                self.addNewPerson(name: name, job: job)
                self.tableView.reloadData()
            }
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    private func addNewPerson(name: String, job: String) {
        let person: Person = getEntity()
        
        person.name = name
        person.job = job
        
        people.append(person)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let transaction = SentrySDK.startTransaction(name: "Sync person database", operation: "data.update", bindToScope: true)
        saveContext()
        transaction.finish()
        super.viewWillDisappear(animated)
    }
}
