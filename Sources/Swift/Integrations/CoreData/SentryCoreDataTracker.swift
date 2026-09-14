// swiftlint:disable missing_docs
internal import _SentryPrivate
internal import CoreData
import Foundation

@_spi(Private) @objc public class SentryCoreDataTracker: NSObject {
    private let predicateDescriptor: SentryPredicateDescriptor
    private let threadInspector: SentryDefaultThreadInspector
    private let processInfoWrapper: SentryProcessInfoSource

    @objc public init(
        threadInspector threadInspectorObject: AnyObject,
        processInfoWrapper: SentryProcessInfoSource
    ) {
        predicateDescriptor = SentryPredicateDescriptor()
        threadInspector = unsafeDowncast(
            threadInspectorObject,
            to: SentryDefaultThreadInspector.self
        )
        self.processInfoWrapper = processInfoWrapper
        super.init()
    }

    @objc(managedObjectContext:executeFetchRequest:error:originalImp:)
    public func __managedObjectContext(
        _ contextObject: AnyObject,
        execute requestObject: AnyObject,
        error: NSErrorPointer,
        originalImp original: (AnyObject, NSErrorPointer) -> [Any]?
    ) -> [Any]! {
        let context = unsafeDowncast(
            contextObject,
            to: NSManagedObjectContext.self
        )
        let request = unsafeDowncast(
            requestObject,
            to: NSFetchRequest<NSFetchRequestResult>.self
        )
        let currentSpan = SentrySDKInternal.currentHub().scope.span as? SentrySpanInternal
        var fetchSpan: SentrySpanInternal?
        if let currentSpan = currentSpan {
            let spanDescription = descriptionFromRequest(request)
            fetchSpan = currentSpan.startChild(
                operation: SentrySpanOperationCoredataFetchOperation,
                description: spanDescription
            ) as? SentrySpanInternal
        }

        if let fetchSpan = fetchSpan {
            fetchSpan.origin = SentryTraceOriginAutoDBCoreData

            SentrySDKLog.debug(
                "SentryCoreDataTracker automatically started a new span with "
                    + "description: \(fetchSpan.spanDescription ?? "(null)"), "
                    + "operation: \(fetchSpan.operation), origin: \(fetchSpan.origin)"
            )
        }

        let result = original(requestObject, error)

        if let fetchSpan = fetchSpan {
            addExtraInfoToSpan(fetchSpan, context: context)

            fetchSpan.setData(value: result?.count ?? 0, key: "read_count")
            fetchSpan.finish(status: result == nil ? .internalError : .ok)

            SentrySDKLog.debug(
                "SentryCoreDataTracker automatically finished span with status: "
                    + (result == nil ? "error" : "ok")
            )
        }

        return result
    }

    @objc(managedObjectContext:save:originalImp:)
    public func managedObjectContext(
        _ contextObject: AnyObject,
        save error: NSErrorPointer,
        originalImp original: (NSErrorPointer) -> Bool
    ) -> Bool {
        let context = unsafeDowncast(
            contextObject,
            to: NSManagedObjectContext.self
        )
        var saveSpan: (any Span)?
        if context.hasChanges {
            let operations = groupEntitiesOperations(context)

            let currentSpan = SentrySDKInternal.currentHub().scope.span
            if let currentSpan = currentSpan {
                let spanDescription = descriptionForOperations(operations, inContext: context)
                saveSpan = currentSpan.startChild(
                    operation: SentrySpanOperationCoredataSaveOperation,
                    description: spanDescription
                )
            }

            if let saveSpan = saveSpan {
                saveSpan.origin = SentryTraceOriginAutoDBCoreData

                SentrySDKLog.debug(
                    "SentryCoreDataTracker automatically started a new span with "
                        + "description: \(saveSpan.spanDescription ?? "(null)"), "
                        + "operation: \(saveSpan.operation), origin: \(saveSpan.origin)"
                )

                saveSpan.setData(value: operations, key: "operations")
            } else {
                SentrySDKLog.error(
                    "managedObjectContext:save:originalImp: saveSpan is nil"
                )
            }
        }

        let result = original(error)

        if let saveSpan = saveSpan {
            addExtraInfoToSpan(
                unsafeDowncast(saveSpan as AnyObject, to: SentrySpanInternal.self),
                context: context
            )
            saveSpan.finish(status: result ? .ok : .internalError)

            SentrySDKLog.debug(
                "SentryCoreDataTracker automatically finished span with status: "
                    + (result ? "ok" : "error")
            )
        }

        return result
    }

    func managedObjectContext(
        _ context: NSManagedObjectContext,
        originalImp original: (NSErrorPointer) -> Bool
    ) throws {
        var error: NSError?
        let result = managedObjectContext(context, save: &error, originalImp: original)
        if !result {
            throw error ?? NSError(domain: NSCocoaErrorDomain, code: 0)
        }
    }

    private func addExtraInfoToSpan(
        _ span: SentrySpanInternal,
        context: NSManagedObjectContext
    ) {
        let isMainThread = Thread.isMainThread

        span.setData(value: isMainThread, key: "blocked_main_thread")
        var systems: [String] = []
        var names: [String] = []
        for store in context.persistentStoreCoordinator?.persistentStores ?? [] {
            systems.append(store.type)
            names.append(store.url?.path ?? "(null)")
        }
        span.setData(value: systems.joined(separator: ";"), key: "db.system")
        span.setData(value: names.joined(separator: ";"), key: "db.name")

        if !isMainThread {
            return
        }

        let stackTrace = threadInspector.stacktraceForCurrentThreadAsyncUnsafe()
        span.frames = stackTrace?.frames
    }

    private func descriptionForOperations(
        _ operations: [String: [String: NSNumber]],
        inContext context: NSManagedObjectContext
    ) -> String {
        var resultParts: [String] = []

        func operationInfo(_ total: Int, _ operation: String) {
            if let items = operations[operation], !items.isEmpty {
                if items.count == 1, let item = items.first {
                    resultParts.append("\(operation) \(item.value) '\(item.key)'")
                } else {
                    resultParts.append("\(operation) \(total) items")
                }
            }
        }

        operationInfo(context.insertedObjects.count, "INSERTED")
        operationInfo(context.updatedObjects.count, "UPDATED")
        operationInfo(context.deletedObjects.count, "DELETED")

        return resultParts.joined(separator: ", ")
    }

    private func groupEntitiesOperations(
        _ context: NSManagedObjectContext
    ) -> [String: [String: NSNumber]] {
        var operations: [String: [String: NSNumber]] = [:]
        operations.reserveCapacity(3)

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

    private func countEntities(
        _ entities: Set<NSManagedObject>
    ) -> [String: NSNumber] {
        var result: [String: NSNumber] = [:]

        for item in entities {
            let className = item.entity.name ?? SwiftDescriptor.getObjectClassName(item)
            let count = result[className]
            result[className] = NSNumber(value: (count?.intValue ?? 0) + 1)
        }

        return result
    }

    private func descriptionFromRequest(
        _ request: NSFetchRequest<NSFetchRequestResult>
    ) -> String {
        var result = "SELECT '\(request.entityName ?? "(null)")'"

        if let predicate = request.predicate {
            result += " WHERE \(predicateDescriptor.predicateDescription(predicate))"
        }

        if let sortDescriptors = request.sortDescriptors, !sortDescriptors.isEmpty {
            result += " SORT BY \(sortDescription(sortDescriptors))"
        }

        return result
    }

    private func sortDescription(_ sortList: [NSSortDescriptor]) -> String {
        var fields: [String] = []
        fields.reserveCapacity(sortList.count)
        for descriptor in sortList {
            let direction = descriptor.ascending ? "" : " DESCENDING"
            fields.append("\(descriptor.key ?? "(null)")\(direction)")
        }
        return fields.joined(separator: ", ")
    }
}
// swiftlint:enable missing_docs
