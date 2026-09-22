#import "SentryDefines.h"
#if SWIFT_PACKAGE
#    import <Foundation/Foundation.h>
#else
@import Sentry;
#endif

/**
 * Written in ObjC, because dealing with the pointers in Swift is super complicated.
 */
@interface SentryTestObjCRuntimeWrapper : NSObject
#if !SWIFT_PACKAGE
                                          <SentryObjCRuntimeWrapper>
#endif

#if SWIFT_PACKAGE
// SwiftPM cannot import a generated Swift header into a Clang module consumed by Swift.
// Declare the methods here; the test target supplies the Swift protocol conformance.
- (const char *_Nonnull *_Nullable)copyClassNamesForImage:(const char *_Nonnull)image
                                                   amount:(unsigned int *_Nullable)outCount
    NS_SWIFT_NAME(copyClassNamesForImage(_:_:));
- (const char *_Nullable)class_getImageName:(Class _Nonnull)cls
    NS_SWIFT_NAME(classGetImageName(_:));
#endif

@property (nullable, nonatomic, copy) void (^beforeGetClassList)(void);

@property (nullable, nonatomic, copy) void (^afterGetClassList)(void);

@property (nullable, nonatomic, copy) int (^numClasses)(int);

@property (nullable, nonatomic, copy) NSArray<NSString *> *_Nullable (^classesNames)
    (NSArray<NSString *> *_Nullable);

@property (nullable, nonatomic) const char *imageName;

@end
