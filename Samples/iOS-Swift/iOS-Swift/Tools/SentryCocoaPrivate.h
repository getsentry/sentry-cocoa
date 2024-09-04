#import <Sentry/Sentry.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryInternalSerializable <NSObject>
- (NSDictionary<NSString *, id> *)serialize;
@end

@interface SentrySdkInfo : NSObject <SentryInternalSerializable>

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *version;

- (instancetype)initWithName:(NSString *)name
                 andVersion:(NSString *)version NS_DESIGNATED_INITIALIZER;

@end

@interface SentryEnvelopeHeader : NSObject

- (instancetype)initWithId:(SentryId *_Nullable)eventId;

@property (nullable, nonatomic, copy) NSDate *sentAt;
@property (nullable, nonatomic, readonly, copy) SentryId *eventId;
@property (nullable, nonatomic, readonly, copy) SentrySdkInfo *sdkInfo;

@end

@interface SentryEnvelopeItem : NSObject

- (instancetype)initWithEvent:(SentryEvent *)event;

@property (nonatomic, readonly, strong) SentryEnvelopeItemHeader *header;
@property (nonatomic, readonly, strong) NSData *data;

@end

@interface SentryEnvelope : NSObject

@property (nonatomic, readonly, strong) SentryEnvelopeHeader *header;
@property (nonatomic, readonly, strong) NSArray<SentryEnvelopeItem *> *items;

- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item;
@end

@interface SentryFileManager : NSObject

- (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

@interface SentryDependencyContainer : NSObject

+ (instancetype)sharedInstance;
@property (nonatomic, strong) SentryFileManager *fileManager;

@end

NS_ASSUME_NONNULL_END
