#import "SentryDefines.h"
#import "SentryObjCRuntimeWrapper.h"

/**
 * Written in ObjC, because dealing with the pointers in Swift is super complicated.
 */
@interface SentryTestObjCRuntimeWrapper : NSObject <SentryObjCRuntimeWrapper>

@property (nullable, nonatomic, copy) void (^beforeGetClassList)(void);

@property (nullable, nonatomic, copy) void (^afterGetClassList)(void);

@property (nullable, nonatomic, copy) int (^numClasses)(int);

@property (nullable, nonatomic, copy) NSArray<NSString *> *_Nullable (^classesNames)
    (NSArray<NSString *> *_Nullable);

@property (nullable, nonatomic) const char *imageName;

@end
