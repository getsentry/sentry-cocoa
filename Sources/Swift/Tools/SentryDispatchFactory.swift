@_spi(Private) @objc public class SentryDispatchFactory: NSObject {
    /// Generate a new @c SentryDispatchQueueWrapper .
    @objc public func queue(withName name: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr) -> SentryDispatchQueueWrapper {
        SentryDispatchQueueWrapper(name: name, attributes: attributes)
    }

     /// Creates a utility QoS queue with the given name and relative priority, wrapped in a @c
     /// SentryDispatchQueueWrapper.
     ///
     /// @note This method is only a factory method and does not keep a reference to the created queue.
     ///
     /// @param name The name of the queue.
     /// @param relativePriority A negative offset from the maximum supported scheduler priority for the
     /// given quality-of-service class. This value must be less than 0 and greater than or equal to @c
     /// QOS_MIN_RELATIVE_PRIORITY, otherwise throws an assertion and returns an unspecified
     /// quality-of-service.
     /// @return Unretained reference to the created queue.
    @objc(createUtilityQueue:relativePriority:) public func createUtilityQueue(_ name: UnsafePointer<CChar>, relativePriority: Int32) -> SentryDispatchQueueWrapper {
        return SentryDispatchQueueWrapper(name: name, relativePriority: relativePriority)
    }

    /// Generate a @c dispatch_source_t by internally vending the required @c SentryDispatchQueueWrapper.
    @objc(sourceWithInterval:leeway:queueName:attributes:eventHandler:) public func source(withInterval interval: NSInteger, leeway: NSInteger, queueName: UnsafePointer<CChar>, attributes: __OS_dispatch_queue_attr, eventHandler: @escaping () -> Void) -> SentryDispatchSourceWrapper {
        SentryDispatchSourceWrapper(interval: interval, leeway: leeway, queue: self.queue(withName: queueName, attributes: attributes), eventHandler: eventHandler)
    }
}
