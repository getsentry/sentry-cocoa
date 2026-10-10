#import <Foundation/Foundation.h>

/**
 * Written in ObjC, because dealing with the pointers in Swift is super complicated.
 */
@interface SentryTestObjCRuntimeWrapper : NSObject

// Conformance to the Swift-owned protocol lives in SentryTestObjCRuntimeWrapper+Protocol.swift.
- (const char *_Nonnull *_Nullable)copyClassNamesForImage:(const char *_Nonnull)image
                                                   amount:(unsigned int *_Nullable)outCount
    NS_SWIFT_NAME(copyClassNamesForImage(_:_:));
- (const char *_Nullable)class_getImageName:(Class _Nonnull)cls
    NS_SWIFT_NAME(classGetImageName(_:));

@property (nullable, nonatomic, copy) void (^beforeGetClassList)(void);

@property (nullable, nonatomic, copy) void (^afterGetClassList)(void);

@property (nullable, nonatomic, copy) int (^numClasses)(int);

@property (nullable, nonatomic, copy) NSArray<NSString *> *_Nullable (^classesNames)
    (NSArray<NSString *> *_Nullable);

@property (nullable, nonatomic) const char *imageName;

@end
