// swiftlint:disable missing_docs
internal import _SentryPrivate
import CoreData

// Exposed to Objective-C for SentryCoreDataSwizzlingHelper.
@_spi(Private) @objc public final class SentryCoreDataTracker: NSObject {
    private let predicateDescriptor = SentryPredicateDescriptor()
    private let threadInspector: SentryDefaultThreadInspector
    private let processInfoWrapper: SentryProcessInfoSource

    @objc public init(threadInspector: SentryDefaultThreadInspector, processInfoWrapper: SentryProcessInfoSource) {
        self.threadInspector = threadInspector
        self.processInfoWrapper = processInfoWrapper
        super.init()
    }

    @objc(managedObjectContext:executeFetchRequest:error:originalImp:)
    public func managedObjectContext(
        _ context: NSManagedObjectContext,
        executeFetchRequest request: NSFetchRequest<NSFetchRequestResult>,
        error: NSErrorPointer,
        originalImp original: (NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray?
    ) -> NSArray? {
        let currentSpan = SentrySDKInternal.currentHub().scope.span
        var fetchSpan: Span?
        if let currentSpan {
            fetchSpan = currentSpan.startChild(
                operation: SentrySpanOperationCoredataFetchOperation,
                description: description(from: request)
            )
        }

        if let fetchSpan {
            fetchSpan.origin = SentryTraceOriginAutoDBCoreData
            SentrySDKLog.debug("SentryCoreDataTracker automatically started a new span with description: \(fetchSpan), operation: \(fetchSpan.operation), origin: \(fetchSpan.origin)")
        }

        let result = original(request, error)

        if let fetchSpan {
            addExtraInfo(to: fetchSpan, context: context)
            fetchSpan.setData(value: result?.count ?? 0, key: "read_count")
            fetchSpan.finish(status: result == nil ? .internalError : .ok)
            SentrySDKLog.debug("SentryCoreDataTracker automatically finished span with status: \(result == nil ? "error" : "ok")")
        }

        return result
    }

    func managedObjectContext(
        _ context: NSManagedObjectContext,
        originalImp original: (NSErrorPointer) -> Bool
    ) throws {
        var error: NSError?
        guard managedObjectContext(context, save: &error, originalImp: original) else {
            // Match the former Objective-C import, including a false result with no NSError.
            throw _convertNSErrorToError(error)
        }
    }

    @objc(managedObjectContext:save:originalImp:)
    public func managedObjectContext(
        _ context: NSManagedObjectContext,
        save error: NSErrorPointer,
        originalImp original: (NSErrorPointer) -> Bool
    ) -> Bool {
        var saveSpan: Span?
        if context.hasChanges {
            let operations = groupEntitiesOperations(context)
            if let currentSpan = SentrySDKInternal.currentHub().scope.span {
                saveSpan = currentSpan.startChild(
                    operation: SentrySpanOperationCoredataSaveOperation,
                    description: description(for: operations, context: context)
                )
            }

            if let saveSpan {
                saveSpan.origin = SentryTraceOriginAutoDBCoreData
                SentrySDKLog.debug("SentryCoreDataTracker automatically started a new span with description: \(saveSpan), operation: \(saveSpan.operation), origin: \(saveSpan.origin)")
                saveSpan.setData(value: operations, key: "operations")
            } else {
                SentrySDKLog.error("managedObjectContext:save:originalImp: saveSpan is nil")
            }
        }

        let result = original(error)

        if let saveSpan {
            addExtraInfo(to: saveSpan, context: context)
            saveSpan.finish(status: result ? .ok : .internalError)
            SentrySDKLog.debug("SentryCoreDataTracker automatically finished span with status: \(result ? "ok" : "error")")
        }

        return result
    }

    private func addExtraInfo(to span: Span, context: NSManagedObjectContext) {
        let isMainThread = Thread.isMainThread
        span.setData(value: isMainThread, key: "blocked_main_thread")

        let stores = context.persistentStoreCoordinator?.persistentStores ?? []
        span.setData(value: stores.map { $0.type }.joined(separator: ";"), key: "db.system")
        span.setData(value: stores.map { $0.url?.path ?? "(null)" }.joined(separator: ";"), key: "db.name")

        guard isMainThread else {
            return
        }
        let stacktrace = threadInspector.stacktraceForCurrentThreadAsyncUnsafe()
        (span as? SentrySpanInternal)?.frames = stacktrace?.frames
    }

    private func description(for operations: [String: [String: Int]], context: NSManagedObjectContext) -> String {
        var resultParts: [String] = []
        func operationInfo(total: Int, operation: String) {
            guard let items = operations[operation], !items.isEmpty else {
                return
            }
            if items.count == 1, let item = items.first {
                resultParts.append("\(operation) \(item.value) '\(item.key)'")
            } else {
                resultParts.append("\(operation) \(total) items")
            }
        }

        operationInfo(total: context.insertedObjects.count, operation: "INSERTED")
        operationInfo(total: context.updatedObjects.count, operation: "UPDATED")
        operationInfo(total: context.deletedObjects.count, operation: "DELETED")
        return resultParts.joined(separator: ", ")
    }

    private func groupEntitiesOperations(_ context: NSManagedObjectContext) -> [String: [String: Int]] {
        var operations: [String: [String: Int]] = [:]
        if !context.insertedObjects.isEmpty {
            operations["INSERTED"] = countEntities(context.insertedObjects)
        }
        if !context.updatedObjects.isEmpty {
            operations["UPDATED"] = countEntities(context.updatedObjects)
        }
        if !context.deletedObjects.isEmpty {
            operations["DELETED"] = countEntities(context.deletedObjects)
        }
        return operations
    }

    private func countEntities(_ entities: Set<NSManagedObject>) -> [String: Int] {
        var result: [String: Int] = [:]
        for entity in entities {
            let name = entity.entity.name ?? SwiftDescriptor.getObjectClassName(entity)
            result[name, default: 0] += 1
        }
        return result
    }

    private func description(from request: NSFetchRequest<NSFetchRequestResult>) -> String {
        var result = "SELECT '\(request.entityName ?? "(null)")'"
        if let predicate = request.predicate {
            result += " WHERE \(predicateDescriptor.predicateDescription(predicate))"
        }
        if let sortDescriptors = request.sortDescriptors, !sortDescriptors.isEmpty {
            result += " SORT BY \(sortDescription(sortDescriptors))"
        }
        return result
    }

    private func sortDescription(_ descriptors: [NSSortDescriptor]) -> String {
        descriptors.map { descriptor in
            let direction = descriptor.ascending ? "" : " DESCENDING"
            return "\(descriptor.key ?? "(null)")\(direction)"
        }.joined(separator: ", ")
    }
}
// swiftlint:enable missing_docs
