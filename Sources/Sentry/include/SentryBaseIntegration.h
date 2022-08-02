#import "SentryOptions.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryOptionWithDescription : NSObject
@property (nonatomic) BOOL option;
@property (strong, nonatomic, nullable) NSString *log;
@property (strong, nonatomic, nullable) NSString *optionName;
- (instancetype)initWithOption:(BOOL)option log:(NSString *)log;
- (instancetype)initWithOption:(BOOL)option optionName:(NSString *)optionName;
@end

@interface SentryBaseIntegration : NSObject

- (NSString *)integrationName;

- (BOOL)isEnabled:(BOOL)option;
- (BOOL)shouldBeEnabled:(NSArray *)options;

@end

NS_ASSUME_NONNULL_END
