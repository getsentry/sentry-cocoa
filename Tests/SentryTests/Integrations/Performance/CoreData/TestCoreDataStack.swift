import CoreData
import Foundation

@objc(TestEntity)
public class TestEntity: NSManagedObject {
    var field1: String?
    var field2: Int?

    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}

@objc(SecondTestEntity)
public class SecondTestEntity: NSManagedObject {
    var field1: String?
    var field2: Int?

    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}

class TestCoreDataStack {
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        
        let buildEntityDescription: ((AnyClass) -> NSEntityDescription) = { (entityClass: AnyClass) in
            let entity = NSEntityDescription()
            entity.name = NSStringFromClass(entityClass)
            entity.managedObjectClassName = entity.name
            
            var properties = [NSAttributeDescription]()
            
            let field1Attribute = NSAttributeDescription()
            field1Attribute.name = "field1"
            field1Attribute.attributeType = .stringAttributeType
            field1Attribute.isOptional = true
            properties.append(field1Attribute)
            
            let field2Attribute = NSAttributeDescription()
            field2Attribute.name = "field2"
            field2Attribute.attributeType = .integer64AttributeType
            field2Attribute.isOptional = true
            properties.append(field2Attribute)
            
            entity.properties = properties
            return entity
        }
        
        let entity1 = buildEntityDescription(TestEntity.self)
        let entity2 = buildEntityDescription(SecondTestEntity.self)
        
        model.entities = [entity1, entity2]
        
        return model
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        
        guard let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        }
            
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
        guard let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
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
