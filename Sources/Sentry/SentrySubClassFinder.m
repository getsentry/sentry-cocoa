#import <Foundation/Foundation.h>
#import <SentrySubClassFinder.h>
#import <objc/runtime.h>

@implementation SentrySubClassFinder

+ (NSArray<Class> *)classGetSubclasses:(Class)parentClass
{
    int amountOfClasses = objc_getClassList(NULL, 0);
    Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * amountOfClasses);
    amountOfClasses = objc_getClassList(classes, amountOfClasses);

    NSMutableArray<Class> *result = [NSMutableArray array];
    for (NSInteger i = 0; i < amountOfClasses; i++) {
        Class superClass = classes[i];
        do {
            superClass = class_getSuperclass(superClass);
        } while (superClass && superClass != parentClass);

        if (superClass == nil) {
            continue;
        }

        [result addObject:classes[i]];
    }

    free(classes);

    return result;
}

@end
