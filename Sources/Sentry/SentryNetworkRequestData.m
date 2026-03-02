#import "SentryNetworkRequestData.h"

NSString *const SentryReplayNetworkDetailsKey = @"_networkDetails";

@interface SentryNetworkRequestData ()
@property (nonatomic, copy, readwrite, nullable) NSString *method;
@property (nonatomic, strong, readwrite, nullable) NSNumber *statusCode;
@property (nonatomic, strong, readwrite, nullable) NSNumber *requestBodySize;
@property (nonatomic, strong, readwrite, nullable) NSNumber *responseBodySize;
@property (nonatomic, strong, readwrite, nullable) SentryReplayNetworkRequestOrResponse *request;
@property (nonatomic, strong, readwrite, nullable) SentryReplayNetworkRequestOrResponse *response;
@end

@implementation SentryNetworkRequestData

- (instancetype)initWithMethod:(nullable NSString *)method
{
    if (self = [super init]) {
        _method = [method copy];
    }
    return self;
}

- (void)setRequestDetails:(SentryReplayNetworkRequestOrResponse *)requestData
{
    self.request = requestData;
    self.requestBodySize = requestData.size;
}

- (void)setResponseDetails:(NSInteger)statusCode
              responseData:(SentryReplayNetworkRequestOrResponse *)responseData
{
    self.statusCode = @(statusCode);
    self.response = responseData;
    self.responseBodySize = responseData.size;
}

- (NSDictionary *)serialize
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    if (self.method) {
        result[@"method"] = self.method;
    }
    if (self.statusCode) {
        result[@"statusCode"] = self.statusCode;
    }
    if (self.requestBodySize) {
        result[@"requestBodySize"] = self.requestBodySize;
    }
    if (self.responseBodySize) {
        result[@"responseBodySize"] = self.responseBodySize;
    }
    if (self.request) {
        result[@"request"] = [self.request serialize];
    }
    if (self.response) {
        result[@"response"] = [self.response serialize];
    }

    return result;
}

- (NSString *)description
{
    NSDictionary *serialized = [self serialize];
    return [NSString stringWithFormat:@"SentryNetworkRequestData: %@", serialized];
}

@end
