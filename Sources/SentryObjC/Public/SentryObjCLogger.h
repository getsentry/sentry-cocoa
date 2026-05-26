#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCLogger : NSObject

- (void)trace:(NSString *)body;
- (void)trace:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

- (void)debug:(NSString *)body;
- (void)debug:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

- (void)info:(NSString *)body;
- (void)info:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

- (void)warn:(NSString *)body;
- (void)warn:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

- (void)error:(NSString *)body;
- (void)error:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

- (void)fatal:(NSString *)body;
- (void)fatal:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

@end

NS_ASSUME_NONNULL_END
