import CoreData
import Foundation

@objc(TestEntity)
public class TestEntity: NSManagedObject {
    var field1: String?
    var field2: Int?
}

class TestCoreDataStack {
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        
        // Create the entity
        let entity = NSEntityDescription()
        entity.name = "TestEntity"
        entity.managedObjectClassName = NSStringFromClass(TestEntity.self) as String
        
        // Create the attributes
        var properties = [NSAttributeDescription]()
        
        let remoteURLAttribute = NSAttributeDescription()
        remoteURLAttribute.name = "field1"
        remoteURLAttribute.attributeType = .stringAttributeType
        remoteURLAttribute.isOptional = true
        properties.append(remoteURLAttribute)
        
        let fileDataAttribute = NSAttributeDescription()
        fileDataAttribute.name = "field2"
        fileDataAttribute.attributeType = .integer64AttributeType
        fileDataAttribute.isOptional = true
        properties.append(fileDataAttribute)
        
        // Add attributes to entity
        entity.properties = properties
        
        // Add entity to model
        model.entities = [entity]
        
        // Done :]
        return model
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        
        guard let tempDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let url = tempDir.appendingPathComponent("SingleViewCoreData.sqlite")
        
        let _ = try? coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        return managedObjectContext
    }()
    
    func reset() {
        guard let tempDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = tempDir.appendingPathComponent("SingleViewCoreData.sqlite")
        try? FileManager.default.removeItem(at: url)
    }
    
    func getEntity<T: NSManagedObject>() -> T {
        guard let entityDescription = NSEntityDescription.entity(forEntityName: NSStringFromClass(T.self), in: managedObjectContext) else {
            fatalError("Core Data entity name doesn't match.")
        }
        let obj = T(entity: entityDescription, insertInto: managedObjectContext)
        return obj
    }
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            try? managedObjectContext.save()
        }
    }
}
