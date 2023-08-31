#import "SentryNSError.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryNSError ()

@property (nonatomic, copy) NSString *domain;
@property (nonatomic, assign) NSInteger code;

/**
 * @note Can be empty, but never @c nil .
 */
@property (nonatomic, copy) NSArray<SentryNSError *> *underlyingErrors;

@end

@implementation SentryNSError

- (instancetype)initWithError:(NSError *)error
{
    if (self = [super init]) {
        _domain = error.domain;
        _code = error.code;

        if (@available(iOS 14.5, tvOS 14.5, macOS 11.3, *)) {
            NSMutableArray<SentryNSError *> *underlyingErrors =
                [NSMutableArray<SentryNSError *> array];
            [error.underlyingErrors enumerateObjectsUsingBlock:^(
                NSError *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                [underlyingErrors addObject:[[SentryNSError alloc] initWithError:obj]];
            }];
            _underlyingErrors = underlyingErrors;
        } else {
            NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
            if (underlyingError == nil) {
                _underlyingErrors = @[];
            } else {
                _underlyingErrors = @[ [[SentryNSError alloc] initWithError:underlyingError] ];
            }
        }
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary<NSString *, id> *dict = [NSMutableDictionary<NSString *, id>
        dictionaryWithObjectsAndKeys:self.domain, @"domain", @(self.code), @"code", nil];
    if (self.underlyingErrors.count > 0) {
        NSMutableArray<NSDictionary<NSString *, id> *> *serializedUnderlyingErrors =
            [NSMutableArray<NSDictionary<NSString *, id> *> array];
        [_underlyingErrors enumerateObjectsUsingBlock:^(SentryNSError *_Nonnull obj, NSUInteger idx,
            BOOL *_Nonnull stop) { [serializedUnderlyingErrors addObject:[obj serialize]]; }];
        dict[@"underlying_errors"] = serializedUnderlyingErrors;
    }
    return dict;
}

@end

NS_ASSUME_NONNULL_END
