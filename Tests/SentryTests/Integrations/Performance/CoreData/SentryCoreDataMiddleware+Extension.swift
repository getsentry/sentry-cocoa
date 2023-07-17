import Foundation

extension SentryCoreDataMiddleware {
    
    func fetchManagedObjectContext<T>(_ context: NSManagedObjectContext, request: NSFetchRequest<T>, isErrorNil: Bool = false, originalImp: (NSFetchRequest<T>, NSErrorPointer) -> [T]?) throws -> [Any] {
        
        var error: NSError?
        var result: [Any]
        
        if isErrorNil {
            result = __managedObjectContext(context, execute: request as! NSFetchRequest<NSFetchRequestResult>, error: nil) { fetchRequest, errorOut in
                return originalImp(fetchRequest as! NSFetchRequest<T>, errorOut)
            }
            
        } else {
            result = __managedObjectContext(context, execute: request as! NSFetchRequest<NSFetchRequestResult>, error: &error) { fetchRequest, errorOut in
                return originalImp(fetchRequest as! NSFetchRequest<T>, errorOut)
            }
        }
        
        if let er = error {
            throw er
        }
    
        return result
    }
    
}
