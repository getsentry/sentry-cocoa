#import "SentryDefines.h"
@import Sentry;

/**
 * Written in ObjC, because dealing with the pointers in Swift is super complicated.
 */
@interface SentryTestObjCRuntimeWrapper : NSObject <SentryObjCRuntimeWrapper>

@property (nullable, nonatomic, copy) void (^beforeGetClassList)(void);

@property (nullable, nonatomic, copy) void (^afterGetClassList)(void);

@property (nullable, nonatomic, copy) int (^numClasses)(int);

@property (nullable, nonatomic, copy) NSArray<NSString *> *_Nullable (^classesNames)
    (NSArray<NSString *> *_Nullable);

/**
 * Overrides the classes returned for an image. Receives the classes the real wrapper found and
 * returns the classes to use. When @c nil, the real implementation is used unchanged.
 */
@property (nullable, nonatomic, copy) NSArray<Class> *_Nonnull (^classes)(NSArray<Class> *_Nonnull);

@property (nullable, nonatomic) const char *imageName;

@end
