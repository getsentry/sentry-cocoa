/**
 * Part of this code was copied from
 * https://github.com/AFNetworking/AFNetworking/blob/4eaec5b586ddd897ebeda896e332a62a9fdab818/AFNetworking/AFURLSessionManager.m#L407-L418
 * under the MIT license
 */

#import "SentrySessionTaskSearch.h"
#import <objc/runtime.h>

@implementation SentrySessionTaskSearch

+ (NSArray<Class> *)urkSessionTaskClassesToTrack
{

    /**
     * In order to be able to track a network request, we need to know when it starts and when it
     * finishes. NSURLSessionTask has a `resume` method that starts the request, and the only way to
     * know when it finishes is to check the task `state`. Using KVO is not working, so we are
     * swizzling `setState:`. Depending on the iOS version NSURLSessionTask does not implements
     * `setState:` and Apple uses a subclass returned by NSURLSession that implementes `setState:`.
     * We need to discover which class to swizzle.
     *
     * Apple intermediate class for iOS does not call [super resume], so we can swizzle both class.
     * This Apple approach may change in the future, we need to have enough tests to detect it
     * early.
     */

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
    NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:nil];
#pragma clang diagnostic pop
    Class currentClass = [localDataTask class];
    NSMutableArray *result = [[NSMutableArray alloc] init];

    SEL setStateSelector = NSSelectorFromString(@"setState:");

    while (class_getInstanceMethod(currentClass, setStateSelector)) {
        Class superClass = [currentClass superclass];
        IMP classResumeIMP
            = method_getImplementation(class_getInstanceMethod(currentClass, setStateSelector));
        IMP superclassResumeIMP
            = method_getImplementation(class_getInstanceMethod(superClass, setStateSelector));
        if (classResumeIMP != superclassResumeIMP) {
            [result addObject:currentClass];
        }
        currentClass = [currentClass superclass];
    }

    [localDataTask cancel];
    [session finishTasksAndInvalidate];
    return [result copy];
}

@end
