import CoreData

/// The explicit arguments of `-[NSManagedObjectContext executeFetchRequest:error:]`.
typealias SentryCoreDataFetchArguments = (NSFetchRequest<NSFetchRequestResult>, NSErrorPointer)

extension SentrySwizzleMethod where Receiver: NSManagedObjectContext, Arguments == SentryCoreDataFetchArguments, Result == NSArray? {
    /// Describes Core Data's fetch method without changing its nullable result or error pointer.
    /// - SeeAlso: `NSManagedObjectContext.fetch(_:)`
    static func managedObjectContextFetch(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(NSManagedObjectContext.__execute(_:)),
            receiver: receiver,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .objectPointer])
        )
    }
}

extension SentrySwizzleMethod where Receiver: NSManagedObjectContext, Arguments == NSErrorPointer, Result == Bool {
    /// Describes Core Data's save method at its Objective-C `BOOL` / `NSError **` boundary.
    /// - SeeAlso: `NSManagedObjectContext.save()`
    static func managedObjectContextSave(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(NSManagedObjectContext.save),
            receiver: receiver,
            signature: .init(returnType: .objcBool, arguments: [.object, .selector, .objectPointer])
        )
    }
}
