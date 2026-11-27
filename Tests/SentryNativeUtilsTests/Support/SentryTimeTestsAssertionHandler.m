#import "SentryTimeTestsAssertionHandler.h"

@implementation SentryTimeTestsAssertionHandler

+ (void)performIgnoringAssertions:(void (^)(void))block
{
    NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
    id previousHandler = threadDictionary[NSAssertionHandlerKey];
    threadDictionary[NSAssertionHandlerKey] = [[self alloc] init];
    @try {
        block();
    } @finally {
        if (previousHandler != nil) {
            threadDictionary[NSAssertionHandlerKey] = previousHandler;
        } else {
            [threadDictionary removeObjectForKey:NSAssertionHandlerKey];
        }
    }
}

- (void)handleFailureInFunction:(NSString *)functionName
                           file:(NSString *)fileName
                     lineNumber:(NSInteger)line
                    description:(NSString *)format, ...
{
    // no-op
}

- (void)handleFailureInMethod:(SEL)selector
                       object:(id)object
                         file:(NSString *)fileName
                   lineNumber:(NSInteger)line
                  description:(NSString *)format, ...
{
    // no-op
}

@end
