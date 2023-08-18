#import "SentryHub.h"

@interface
SentryHub ()

@property (nonatomic, strong) NSMutableArray<id<SentryIntegrationProtocol>> *installedIntegrations;
@property (nonatomic, strong) NSMutableSet<NSString *> *installedIntegrationNames;

@end
