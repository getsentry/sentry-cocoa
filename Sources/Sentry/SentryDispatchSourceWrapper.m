#import "SentryDispatchSourceWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDispatchSourceWrapper {
    dispatch_source_t _source;
}

- (instancetype)initWithDispatchSource:(dispatch_source_t)source
{
    if (self = [super init]) {
        _source = source;
    }
    return self;
}

- (void)resumeWithHandler:(dispatch_block_t)handler
{
    dispatch_source_set_event_handler(_source, handler);
    dispatch_resume(_source);
}

- (uintptr_t)getData
{
    return dispatch_source_get_data(_source);
}

- (void)invalidate
{
    dispatch_source_cancel(_source);
}

@end

@implementation SentryDispatchSourceFactory

- (SentryDispatchSourceWrapper *)dispatchSourceWithType:(dispatch_source_type_t)type
                                                 handle:(uintptr_t)handle
                                                   mask:(uintptr_t)mask
                                                  queue:(dispatch_queue_t _Nullable)sourceQueue;
{
    dispatch_source_t source = dispatch_source_create(type, handle, mask, sourceQueue);
    return [[SentryDispatchSourceWrapper alloc] initWithDispatchSource:source];
}

@end

NS_ASSUME_NONNULL_END
