#import "SentryDefines.h"
#import "SentryObjCRuntimeWrapper.h"

/**
 * Written in ObjC, because dealing with the pointers in Swift is super complicated.
 */
@interface SentryTestObjCRuntimeWrapper : NSObject <SentryObjCRuntimeWrapper>

@property (nullable, nonatomic, copy) void (^beforeGetClassList)(void);

@property (nullable, nonatomic, copy) int (^numClasses)(int);

@property (nonatomic, assign) NSUInteger iterateClassesInvocations;

@end
