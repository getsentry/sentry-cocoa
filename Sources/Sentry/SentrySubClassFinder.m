#import "SentrySubClassFinder.h"
#import "SentryLog.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@implementation SentrySubClassFinder

+ (NSArray<Class> *)getSubclassesOf:(Class)parentClass
{
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);

    NSMutableArray<Class> *result = [NSMutableArray new];

    if (numClasses <= 0) {
        [SentryLog logWithMessage:@"No classes found when retrieving class list."
                         andLevel:kSentryLevelError];
        return result;
    }

    for (NSInteger i = 0; i < numClasses; i++) {
        Class superClass = classes[i];
        do {
            superClass = class_getSuperclass(superClass);
        } while (superClass && superClass != parentClass);

        if (superClass != nil) {
            [result addObject:classes[i]];
        }
    }

    free(classes);

    return result;
}

@end
