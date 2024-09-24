#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A subclass of NSString containing an invalid JSON string. This class is helpful in writing tests
 * for NSJSONSerialization to create invalid JSON objects. Furthermore, you can use
 * initWithLengthInvocationsToBeInvalid to specify after how many NSString.length invocations, the
 * string should become an invalid JSON object.
 */
@interface SentryInvalidJSONString : NSString

- (instancetype)initWithLengthInvocationsToBeInvalid:(NSInteger)lengthInvocationsToBeInvalid;

@end

NS_ASSUME_NONNULL_END
