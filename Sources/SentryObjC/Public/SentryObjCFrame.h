#import <Foundation/Foundation.h>

#import "SentryObjCSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A single frame in a stack trace.
 *
 * @see SentryStacktrace
 */
@interface SentryFrame : NSObject <SentrySerializable>

@property (nonatomic, copy) NSString *symbolAddress;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *function;
@property (nonatomic, copy) NSString *module;
@property (nonatomic, copy) NSString *package;
@property (nonatomic, copy) NSString *imageAddress;
@property (nonatomic, copy) NSString *platform;
@property (nonatomic, copy) NSString *instructionAddress;
@property (nonatomic, copy) NSNumber *lineNumber;
@property (nonatomic, copy) NSNumber *columnNumber;
@property (nonatomic, copy) NSString *contextLine;
@property (nonatomic, copy) NSArray<NSString *> *preContext;
@property (nonatomic, copy) NSArray<NSString *> *postContext;
@property (nonatomic, copy) NSNumber *inApp;
@property (nonatomic, copy) NSNumber *stackStart;
@property (nonatomic, copy) NSDictionary<NSString *, id> *vars;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
