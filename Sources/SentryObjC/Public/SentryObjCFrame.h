#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCFrame : NSObject

@property (nonatomic, copy, nullable) NSString *symbolAddress;
@property (nonatomic, copy, nullable) NSString *fileName;
@property (nonatomic, copy, nullable) NSString *function;
@property (nonatomic, copy, nullable) NSString *module;
@property (nonatomic, copy, nullable) NSString *package;
@property (nonatomic, copy, nullable) NSString *imageAddress;
@property (nonatomic, copy, nullable) NSString *platform;
@property (nonatomic, copy, nullable) NSString *instructionAddress;
@property (nonatomic, copy, nullable) NSNumber *lineNumber;
@property (nonatomic, copy, nullable) NSNumber *columnNumber;
@property (nonatomic, copy, nullable) NSString *contextLine;
@property (nonatomic, copy, nullable) NSNumber *parentIndex;
@property (nonatomic, copy, nullable) NSNumber *sampleCount;
@property (nonatomic, copy, nullable) NSArray<NSString *> *preContext;
@property (nonatomic, copy, nullable) NSArray<NSString *> *postContext;
@property (nonatomic, copy, nullable) NSNumber *inApp;
@property (nonatomic, copy, nullable) NSNumber *stackStart;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *vars;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
