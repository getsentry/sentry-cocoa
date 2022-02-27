import Foundation

extension SentryCoreDataMiddleware {
    
    func fetchManagedObjectContext<T>(_ context : NSManagedObjectContext, request : NSFetchRequest<T>,  originalImp: (NSFetchRequest<T>, NSErrorPointer) -> [T]?) throws -> [T] where T : NSFetchRequestResult {
        
        var error : NSError? = nil
        
        let result = __managedObjectContext(context, execute: request as! NSFetchRequest<NSFetchRequestResult>, error: &error) { fetchRequest, errorOut in
            return originalImp(fetchRequest as! NSFetchRequest<T>, errorOut)
        }
        
        if let er = error {
            throw er
        }
    
        return result as? [T] ?? []
    }
    
}
