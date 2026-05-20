#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A log message that describes an event or error.
@interface SentryCompatMessage : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithFormatted:(NSString *)formatted;

@property (nonatomic, readonly, copy) NSString *formatted;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSArray<NSString *> *params;

@end

NS_ASSUME_NONNULL_END
