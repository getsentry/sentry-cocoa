#import <SentryAppMemory.h>
#import <SentryDateUtils.h>

#import <mach/mach.h>
#import <mach/task.h>
#import <atomic>

NS_ASSUME_NONNULL_BEGIN

/**
 The memory tracker takes care of centralizing the knowledge around memory.
 It does the following:
 
 1- Wraps memory pressure. This is more useful than `didReceiveMemoryWarning`
 as it vends different levels of pressure caused by the app as well as the rest of the OS.
 
 2- Vends a memory level. This is pretty novel. It vends levels of where the app is wihtin
 the memory limit.
 
 Some useful info. 
 
 Memory Pressure is mostly useful when the app is in the background.
 It helps understand how much `pressure` is on the app due to external concerns. Using
 this data, we can make informed decisions around the reasons the app might have been
 terminated.
 
 Memory Level is useful in the foreground as well as background. It indicates where the app is
 within its memory limit. That limit being calculated by the addition of `remaining` and `footprint`.
 Using this data, we can also make informaed decisions around foreground and background memory
 terminations, aka. OOMs.
 
 See: https://github.com/naftaly/Footprint
 */
@interface SentryAppMemoryTracker : NSObject {
    dispatch_queue_t _heartbeatQueue;
    dispatch_source_t _pressureSource;
    dispatch_source_t _limitSource;
    std::atomic<SentryAppMemoryPressure> _pressure;
    std::atomic<SentryAppMemoryLevel> _level;
}

+ (instancetype)shared;

@property (atomic, readonly) SentryAppMemoryPressure pressure;

@end

@implementation SentryAppMemoryTracker

// For memory tracking to be useful it needs to start early.
// This adds a dash of startup time.
// For simplicity sake, I've strted it here for now.
+ (void)load
{
    (void)SentryAppMemoryTracker.shared;
}

+ (instancetype)shared
{
    static SentryAppMemoryTracker *sTracker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sTracker = [SentryAppMemoryTracker new];
        [sTracker start];
    });
    return sTracker;
}

- (instancetype)init
{
    if (self = [super init]) {
        _heartbeatQueue = dispatch_queue_create_with_target("io.sentry.memory.heartbeat", DISPATCH_QUEUE_SERIAL, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        _level = SentryAppMemoryLevelNormal;
        _pressure = SentryAppMemoryPressureNormal;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (void)start
{
    // kill the old ones
    if (_pressureSource || _limitSource) {
        [self stop];
    }

    // memory pressure
    uintptr_t mask = DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL;
    _pressureSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0, mask, dispatch_get_main_queue());
    
    __weak __typeof(self)weakMe = self;
    
    dispatch_source_set_event_handler(_pressureSource, ^{
        [weakMe _memoryPressureChanged:YES];
    });
    dispatch_activate(_pressureSource);

    // memory limit (level)
    _limitSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _heartbeatQueue);
    dispatch_source_set_event_handler(_limitSource, ^{
        [weakMe _heartbeat:YES];
    });
    dispatch_source_set_timer(_limitSource, dispatch_time(DISPATCH_TIME_NOW, 0), NSEC_PER_SEC, NSEC_PER_SEC/10);
    dispatch_activate(_limitSource);
}

- (void)stop
{
    if (_pressureSource) {
        dispatch_source_cancel(_pressureSource);
        _pressureSource = nil;
    }
    
    if (_limitSource) {
        dispatch_source_cancel(_limitSource);
        _limitSource = nil;
    }
}

- (void)_heartbeat:(BOOL)sendObservers
{
    // This handles the memory limit.
    SentryAppMemoryLevel newLevel = [SentryAppMemory current].level;
    SentryAppMemoryLevel oldLevel = _level.exchange(newLevel);
    if (newLevel != oldLevel && sendObservers) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SentryAppMemoryLevelChangedNotification object:self userInfo:@{
                SentryAppMemoryNewValueKey: @(newLevel),
                SentryAppMemoryOldValueKey: @(oldLevel)
            }];
        });
#if TARGET_OS_SIMULATOR
      
        // On the simulator, if we're at a terminal level
        // let's fake an OOM by sending a SIGKILL signal
        //
        // NOTE: Some teams might want to do this in prod.
        // For example, we could send a SIGTERM so the system
        // catches a stack trace.
        if (newLevel == SentryAppMemoryLevelTerminal) {
            kill(getpid(), SIGKILL);
            _exit(0);
        }
#endif
    }
}

- (void)_memoryPressureChanged:(BOOL)sendObservers
{
    // This handles system based memory pressure.
    SentryAppMemoryPressure pressure = SentryAppMemoryPressureNormal;
    dispatch_source_memorypressure_flags_t flags = dispatch_source_get_data(_pressureSource);
    if (flags == DISPATCH_MEMORYPRESSURE_NORMAL) {
        pressure = SentryAppMemoryPressureNormal;
    } else if (flags == DISPATCH_MEMORYPRESSURE_WARN) {
        pressure = SentryAppMemoryPressureWarn;
    } else if (flags == DISPATCH_MEMORYPRESSURE_CRITICAL) {
        pressure = SentryAppMemoryPressureCritical;
    }
    SentryAppMemoryPressure oldPressure = _pressure.exchange(pressure);
    if (oldPressure != pressure && sendObservers) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SentryAppMemoryPressureChangedNotification object:self userInfo:@{
            SentryAppMemoryNewValueKey: @(pressure),
            SentryAppMemoryOldValueKey: @(oldPressure)
        }];
    }
}

- (SentryAppMemoryPressure)pressure
{
    return _pressure.load();
}

- (SentryAppMemoryLevel)level
{
    return _level.load();
}

@end

@implementation SentryAppMemory

+ (nullable instancetype)current
{
    task_vm_info_data_t         info = {};
    mach_msg_type_number_t      count = TASK_VM_INFO_COUNT;
    kern_return_t               err = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
    if (err != KERN_SUCCESS) {
        return nil;
    }
    
    uint64_t remaining = info.limit_bytes_remaining;
#if TARGET_OS_SIMULATOR
    // in simulator, remaining is always 0. So let's fake it. 
    // How about a limit of 3GB.
    uint64_t limit = 3000000000;
    remaining = limit < info.phys_footprint ? 0 : limit - info.phys_footprint;
#endif
    
    return [[self alloc] initWithFootprint:info.phys_footprint
                                 remaining:remaining
                                  pressure:SentryAppMemoryTracker.shared.pressure];
}

- (instancetype)initWithFootprint:(uint64_t)footprint remaining:(uint64_t)remaining pressure:(SentryAppMemoryPressure)pressure
{
    if (self = [super init]) {
        _footprint = footprint;
        _remaining = remaining;
        _pressure = pressure;
    }
    return self;
}

- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject
{
    NSNumber *const footprintRef = jsonObject[@"footprint"];
    NSNumber *const remainingRef = jsonObject[@"remaining"];
    NSString *const pressureRef = jsonObject[@"pressure"];
    
    uint64_t footprint = 0;
    if ([footprintRef isKindOfClass:NSNumber.class]) {
        footprint = footprintRef.unsignedLongLongValue;
    } else {
        return nil;
    }
    
    uint64_t remaining = 0;
    if ([remainingRef isKindOfClass:NSNumber.class]) {
        remaining = remainingRef.unsignedLongLongValue;
    } else {
        return nil;
    }
    
    SentryAppMemoryPressure pressure = SentryAppMemoryPressureNormal;
    if ([pressureRef isKindOfClass:NSString.class]) {
        pressure = SentryAppMemoryPressureFromString(pressureRef);
    }
    
    return [self initWithFootprint:footprint
                         remaining:remaining
                          pressure:pressure];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    SentryAppMemory *comp = (SentryAppMemory *)object;
    return comp.footprint == self.footprint &&
    comp.remaining == self.remaining &&
    comp.pressure == self.pressure;
}

- (nonnull NSDictionary<NSString *,id> *)serialize
{
    return @{
        @"footprint": @(self.footprint),
        @"remaining": @(self.remaining),
        @"limit": @(self.limit),
        @"level": SentryAppMemoryLevelToString(self.level),
        @"pressure": SentryAppMemoryPressureToString(self.pressure)
    };
}

- (uint64_t)limit 
{
    return _footprint + _remaining;
}

- (SentryAppMemoryLevel)level
{
    double usedRatio = (double)self.footprint/(double)self.limit;
    
    return usedRatio < 0.25 ? SentryAppMemoryLevelNormal :
    usedRatio < 0.50 ? SentryAppMemoryLevelWarn :
    usedRatio < 0.75 ? SentryAppMemoryLevelUrgent :
    usedRatio < 0.95 ? SentryAppMemoryLevelCritical : SentryAppMemoryLevelTerminal;
}

- (BOOL)isLikelyOutOfMemory
{
    return self.level >= SentryAppMemoryLevelCritical || self.pressure >= SentryAppMemoryPressureCritical;
}

@end

NSString *SentryAppMemoryLevelToString(SentryAppMemoryLevel level)
{
    switch (level) {
        case SentryAppMemoryLevelNormal: return @"normal";
        case SentryAppMemoryLevelWarn: return @"warn";
        case SentryAppMemoryLevelUrgent: return @"urgent";
        case SentryAppMemoryLevelCritical: return @"critical";
        case SentryAppMemoryLevelTerminal: return @"terminal";
    }
}

SentryAppMemoryLevel SentryAppMemoryLevelFromString(NSString *const level)
{
    if ([level isEqualToString:@"normal"]) {
        return SentryAppMemoryLevelNormal;
    }
    
    if ([level isEqualToString:@"warn"]) {
        return SentryAppMemoryLevelWarn;
    }
    
    if ([level isEqualToString:@"urgent"]) {
        return SentryAppMemoryLevelUrgent;
    }
    
    if ([level isEqualToString:@"critical"]) {
        return SentryAppMemoryLevelCritical;
    }
    
    if ([level isEqualToString:@"terminal"]) {
        return SentryAppMemoryLevelTerminal;
    }
    
    return SentryAppMemoryLevelNormal;
}

NSString *SentryAppMemoryPressureToString(SentryAppMemoryPressure pressure)
{
    switch (pressure) {
        case SentryAppMemoryPressureNormal: return @"normal";
        case SentryAppMemoryPressureWarn: return @"warn";
        case SentryAppMemoryPressureCritical: return @"critical";
    }
}

SentryAppMemoryPressure SentryAppMemoryPressureFromString(NSString *const pressure)
{
    if ([pressure isEqualToString:@"normal"]) {
        return SentryAppMemoryPressureNormal;
    }
    
    if ([pressure isEqualToString:@"warn"]) {
        return SentryAppMemoryPressureWarn;
    }
    
    if ([pressure isEqualToString:@"critical"]) {
        return SentryAppMemoryPressureCritical;
    }
    
    return SentryAppMemoryPressureNormal;
}

NSNotificationName const SentryAppMemoryLevelChangedNotification = @"SentryAppMemoryLevelChangedNotification";
NSNotificationName const SentryAppMemoryPressureChangedNotification = @"SentryAppMemoryPressureChangedNotification";
NSString *const SentryAppMemoryNewValueKey = @"SentryAppMemoryNewValueKey";
NSString *const SentryAppMemoryOldValueKey = @"SentryAppMemoryOldValueKey";

NS_ASSUME_NONNULL_END
