#import "SentryProfiler.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "NSDate+SentryExtras.h"
#    import "SentryBacktrace.hpp"
#    import "SentryClient+Private.h"
#    import "SentryCurrentDate.h"
#    import "SentryDebugImageProvider.h"
#    import "SentryDebugMeta.h"
#    import "SentryDefines.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDevice.h"
#    import "SentryEnvelope.h"
#    import "SentryEnvelopeItemType.h"
#    import "SentryFramesTracker.h"
#    import "SentryHexAddressFormatter.h"
#    import "SentryHub+Private.h"
#    import "SentryId.h"
#    import "SentryLog.h"
#    import "SentrySamplingProfiler.hpp"
#    import "SentryScope+Private.h"
#    import "SentryScreenFrames.h"
#    import "SentrySerialization.h"
#    import "SentrySpanId.h"
#    import "SentryThread.h"
#    import "SentryTime.h"
#    import "SentryTransaction.h"
#    import "SentryTransactionContext+Private.h"
#    import "minijson_writer.hpp"

#    if defined(DEBUG)
#        include <execinfo.h>
#    endif

#    import <cstdint>
#    import <memory>
#    import <fstream>
#    import <sstream>
#    import <unordered_map>
#    import <mutex>

#    if TARGET_OS_IOS
#        import <UIKit/UIKit.h>
#    endif

using namespace sentry::profiling;

__attribute__((objc_direct_members))
@interface SentryJSONObjectStream : NSObject
@property (nonatomic, strong, readonly) NSURL *fileURL;
- (instancetype)initWithFileURL:(NSURL *)fileURL;
- (void)flush;
- (void)close;
- (std::shared_ptr<minijson::object_writer>)writer;
@end

__attribute__((objc_direct_members))
@interface SentryJSONArrayStream : NSObject
@property (nonatomic, strong, readonly) NSURL *fileURL;
- (void)flush;
- (void)close;
- (instancetype)initWithFileURL:(NSURL *)fileURL;
- (std::shared_ptr<minijson::array_writer>)writer;
@end

const int kSentryProfilerFrequencyHz = 101;

namespace {
std::mutex _gProfilerLock;
NSMutableDictionary<SentrySpanId *, SentryProfiler *> *_gProfilersPerSpanID;
SentryProfiler *_Nullable _gCurrentProfiler;

#    if defined(DEBUG)
NSString *
parseBacktraceSymbolsFunctionName(const char *symbol)
{
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression
            regularExpressionWithPattern:@"\\d+\\s+\\S+\\s+0[xX][0-9a-fA-F]+\\s+(.+)\\s+\\+\\s+\\d+"
                                 options:0
                                   error:nil];
    });
    const auto symbolNSStr = [NSString stringWithUTF8String:symbol];
    const auto match = [regex firstMatchInString:symbolNSStr
                                         options:0
                                           range:NSMakeRange(0, [symbolNSStr length])];
    if (match == nil) {
        return symbolNSStr;
    }
    return [symbolNSStr substringWithRange:[match rangeAtIndex:1]];
}
#endif

std::string formatHex(std::uint64_t v) {
    std::stringstream stream;
    stream << "0x" << std::hex << std::setw(16) << std::setfill('0') << v;
    return stream.str();
}

void
processBacktrace(const Backtrace &backtrace,
    std::shared_ptr<std::unordered_map<thread::TIDType, ThreadMetadata>> threadMetadata,
    std::shared_ptr<std::unordered_map<std::uint64_t, QueueMetadata>> queueMetadata,
    SentryJSONArrayStream *samplesStream,
    SentryJSONArrayStream *stacksStream,
    std::shared_ptr<std::uint64_t> stacksCount,
    SentryJSONArrayStream *framesStream,
    std::shared_ptr<std::uint64_t> framesCount,
    std::shared_ptr<std::unordered_map<std::uint64_t, std::uint64_t>> frameIndexLookupPtr,
                 uint64_t startTimestamp)
{
    const auto threadID = backtrace.threadMetadata.threadID;
    auto &threadMetadataRef = (*threadMetadata)[threadID];
    if (threadMetadataRef.name.empty()) {
        threadMetadataRef.threadID = backtrace.threadMetadata.threadID;
        threadMetadataRef.name = backtrace.threadMetadata.name;
    }
    if (threadMetadataRef.priority == 0 && backtrace.threadMetadata.priority != -1) {
        threadMetadataRef.priority = backtrace.threadMetadata.priority;
    }
    
    const auto queueAddress = backtrace.queueMetadata.address;
    if (queueAddress != 0) {
        auto &queueMetadataRef = (*queueMetadata)[queueAddress];
        queueMetadataRef.address = queueAddress;
        if (queueMetadataRef.label == nullptr && backtrace.queueMetadata.label != nullptr) {
            queueMetadataRef.label = backtrace.queueMetadata.label;
        }
    }
    
    const auto newStackIndex = *stacksCount;
    {
        auto stackWriter = stacksStream.writer->nested_array();
        auto &frameIndexLookup = *frameIndexLookupPtr;
#    if defined(DEBUG)
        const auto symbols
            = backtrace_symbols(reinterpret_cast<void *const *>(backtrace.addresses.data()),
                                static_cast<int>(backtrace.addresses.size()));
#    endif
        for (std::vector<uintptr_t>::size_type backtraceAddressIdx = 0;
             backtraceAddressIdx < backtrace.addresses.size(); backtraceAddressIdx++) {
            const auto address = backtrace.addresses[backtraceAddressIdx];
            auto frameIndexIt = frameIndexLookup.find(address);
            auto newFrameIndex = *framesCount;
            if (frameIndexIt != frameIndexLookup.end()) {
                newFrameIndex = frameIndexIt->second;
            } else {
                {
                    auto frameWriter = framesStream.writer->nested_object();
                    frameWriter.write("instruction_addr", formatHex(address));
    #    if defined(DEBUG)
                    frameWriter.write("function", [parseBacktraceSymbolsFunctionName(symbols[backtraceAddressIdx]) cStringUsingEncoding:NSUTF8StringEncoding]);
    #    endif
                    frameWriter.close();
                }
                frameIndexLookup[address] = newFrameIndex;
                (*framesCount)++;
            }
            stackWriter.write(newFrameIndex);
        }
        stackWriter.close();
        (*stacksCount)++;
    }
    
    {
        auto sampleWriter = samplesStream.writer->nested_object();
        sampleWriter.write("elapsed_since_start_ns", getDurationNs(startTimestamp, backtrace.absoluteTimestamp));
        sampleWriter.write("stack_id", newStackIndex);
        sampleWriter.write("thread_id", backtrace.threadMetadata.threadID);
        if (queueAddress != 0) {
            sampleWriter.write("queue_address", formatHex(queueAddress));
        }
        sampleWriter.close();
    }
}

NSURL *temporaryFileURL() {
    const auto temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [temporaryDirectoryURL URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
}

struct write_json_array_from_file
{
    void operator()(std::ostream& stream, const char *path, minijson::writer_configuration) const {
        std::ifstream inputStream;
        inputStream.open(path);
        stream << inputStream.rdbuf() << ']';
        inputStream.close();
    }
};
} // namespace

NSString *
profilerTruncationReasonName(SentryProfilerTruncationReason reason)
{
    switch (reason) {
    case SentryProfilerTruncationReasonNormal:
        return @"normal";
    case SentryProfilerTruncationReasonAppMovedToBackground:
        return @"backgrounded";
    case SentryProfilerTruncationReasonTimeout:
        return @"timeout";
    }
}

@implementation SentryProfiler {
    uint64_t _startTimestamp;
    NSDate *_startDate;
    NSDate *_endDate;
    std::shared_ptr<SamplingProfiler> _profiler;
    std::mutex _lock;
    SentryDebugImageProvider *_debugImageProvider;

    NSMutableArray<SentrySpanId *> *_spansInFlight;
    NSMutableArray<SentryTransaction *> *_transactions;
    SentryProfilerTruncationReason _truncationReason;
    SentryScreenFrames *_frameInfo;
    NSTimer *_timeoutTimer;
    SentryHub *__weak _hub;
    
    SentryJSONArrayStream *_framesStream;
    SentryJSONArrayStream *_stacksStream;
    SentryJSONArrayStream *_samplesStream;
    std::shared_ptr<std::unordered_map<thread::TIDType, ThreadMetadata>> _threadMetadata;
    std::shared_ptr<std::unordered_map<std::uint64_t, QueueMetadata>> _queueMetadata;
}

+ (void)initialize
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    if (self == [SentryProfiler class]) {
        _gProfilersPerSpanID = [NSMutableDictionary<SentrySpanId *, SentryProfiler *> dictionary];
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

#    if SENTRY_TARGET_PROFILING_SUPPORTED
- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    SENTRY_LOG_DEBUG(@"Initialized new SentryProfiler %@", self);
    _debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;
    _spansInFlight = [NSMutableArray<SentrySpanId *> array];
    _transactions = [NSMutableArray<SentryTransaction *> array];
    return self;
}
#    endif

#    pragma mark - Public

+ (void)startForSpanID:(SentrySpanId *)spanID hub:(SentryHub *)hub
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    NSTimeInterval timeoutInterval = 30;
#        if defined(TEST) || defined(TESTCI)
    timeoutInterval = 1;
#        endif
    [self startForSpanID:spanID hub:hub timeoutInterval:timeoutInterval];
#    endif
}

+ (void)startForSpanID:(SentrySpanId *)spanID
                   hub:(SentryHub *)hub
       timeoutInterval:(NSTimeInterval)timeoutInterval
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        _gCurrentProfiler = [[SentryProfiler alloc] init];
        if (_gCurrentProfiler == nil) {
            SENTRY_LOG_WARN(@"Profiler was not initialized, will not proceed.");
            return;
        }
#        if SENTRY_HAS_UIKIT
        [SentryFramesTracker.sharedInstance resetProfilingTimestamps];
#        endif // SENTRY_HAS_UIKIT
        [_gCurrentProfiler start];
        _gCurrentProfiler->_timeoutTimer =
            [NSTimer scheduledTimerWithTimeInterval:10
                                             target:self
                                           selector:@selector(timeoutAbort)
                                           userInfo:nil
                                            repeats:NO];
#        if SENTRY_HAS_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundAbort)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
#        endif // SENTRY_HAS_UIKIT
        _gCurrentProfiler->_hub = hub;
    }

    SENTRY_LOG_DEBUG(
        @"Tracking span with ID %@ with profiler %@", spanID.sentrySpanIdString, _gCurrentProfiler);
    [_gCurrentProfiler->_spansInFlight addObject:spanID];
    _gProfilersPerSpanID[spanID] = _gCurrentProfiler;
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (void)stopProfilingSpan:(id<SentrySpan>)span
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(
            @"No profiler tracking span with id %@", span.context.spanId.sentrySpanIdString);
        return;
    }

    [_gCurrentProfiler->_spansInFlight removeObject:span.context.spanId];
    if (_gCurrentProfiler->_spansInFlight.count == 0) {
        SENTRY_LOG_DEBUG(@"Stopping profiler %@ because span with id %@ was last being profiled.",
            _gCurrentProfiler, span.context.spanId.sentrySpanIdString);
//        [self stopProfilerForReason:SentryProfilerTruncationReasonNormal];
    }
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (void)dropTransaction:(SentryTransaction *)transaction
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    const auto spanID = transaction.trace.context.spanId;
    const auto profiler = _gProfilersPerSpanID[spanID];
    if (profiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler tracking span with id %@", spanID.sentrySpanIdString);
        return;
    }

//    [self captureEnvelopeIfFinished:profiler spanID:spanID];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (void)linkTransaction:(SentryTransaction *)transaction
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);

    const auto spanID = transaction.trace.context.spanId;
    SentryProfiler *profiler = _gProfilersPerSpanID[spanID];
    if (profiler == nil) {
        SENTRY_LOG_DEBUG(@"No profiler tracking span with id %@", spanID.sentrySpanIdString);
        return;
    }

    SENTRY_LOG_DEBUG(@"Found profiler waiting for span with ID %@: %@",
        transaction.trace.context.spanId.sentrySpanIdString, profiler);
    [profiler addTransaction:transaction];

//    [self captureEnvelopeIfFinished:profiler spanID:spanID];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

+ (BOOL)isRunning
{
#    if SENTRY_TARGET_PROFILING_SUPPORTED
    std::lock_guard<std::mutex> l(_gProfilerLock);
    return [_gCurrentProfiler isRunning];
#    endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

#    pragma mark - Private

+ (void)captureEnvelopeIfFinished:(SentryProfiler *)profiler spanID:(SentrySpanId *)spanID
{
    [_gProfilersPerSpanID removeObjectForKey:spanID];
    [profiler->_spansInFlight removeObject:spanID];
    if (profiler->_spansInFlight.count == 0) {
        [profiler captureEnvelope];
        [profiler->_transactions removeAllObjects];
    } else {
        SENTRY_LOG_DEBUG(@"Profiler %@ is waiting for more spans to complete.", profiler);
    }
}

+ (void)timeoutAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No current profiler to stop.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
    [_gCurrentProfiler captureEnvelope];
    [self stopProfilerForReason:SentryProfilerTruncationReasonTimeout];
}

+ (void)backgroundAbort
{
    std::lock_guard<std::mutex> l(_gProfilerLock);

    if (_gCurrentProfiler == nil) {
        SENTRY_LOG_DEBUG(@"No current profiler to stop.");
        return;
    }

    SENTRY_LOG_DEBUG(@"Stopping profiler %@ due to timeout.", _gCurrentProfiler);
   // [self stopProfilerForReason:SentryProfilerTruncationReasonAppMovedToBackground];
}

+ (void)stopProfilerForReason:(SentryProfilerTruncationReason)reason
{
    [_gCurrentProfiler->_timeoutTimer invalidate];
    [_gCurrentProfiler stop];
    _gCurrentProfiler->_truncationReason = reason;
#    if SENTRY_HAS_UIKIT
    _gCurrentProfiler->_frameInfo = SentryFramesTracker.sharedInstance.currentFrames;
    [SentryFramesTracker.sharedInstance resetProfilingTimestamps];
#    endif // SENTRY_HAS_UIKIT
    _gCurrentProfiler = nil;
}

- (void)start
{
    NSLog(@"[INDRAGIE] START");
    // Disable profiling when running with TSAN because it produces a TSAN false
    // positive, similar to the situation described here:
    // https://github.com/envoyproxy/envoy/issues/2561
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
    SENTRY_LOG_DEBUG(@"Disabling profiling when running with TSAN");
    return;
#            pragma clang diagnostic push
#            pragma clang diagnostic ignored "-Wunreachable-code"
#        endif
#    endif
#    pragma clang diagnostic pop
    std::lock_guard<std::mutex> l(_lock);
    if (_profiler != nullptr) {
        _profiler->stopSampling();
    }
    /*
     * Maintain an index of unique frames to avoid duplicating large amounts of data. Every
     * unique frame is stored in an array, and every time a stack trace is captured for a
     * sample, the stack is stored as an array of integers indexing into the array of frames.
     * Stacks are thusly also stored as unique elements in their own index, an array of arrays
     * of frame indices, and each sample references a stack by index, to deduplicate common
     * stacks between samples, such as when the same deep function call runs across multiple
     * samples.
     *
     * E.g. if we have the following samples in the following function call stacks:
     *
     *              v sample1    v sample2               v sample3    v sample4
     * |-foo--------|------------|-----|    |-abc--------|------------|-----|
     *    |-bar-----|------------|--|          |-def-----|------------|--|
     *      |-baz---|------------|-|             |-ghi---|------------|-|
     *
     * Then we'd wind up with the following structures:
     *
     * frames: [
     *   { function: foo, instruction_addr: ... },
     *   { function: bar, instruction_addr: ... },
     *   { function: baz, instruction_addr: ... },
     *   { function: abc, instruction_addr: ... },
     *   { function: def, instruction_addr: ... },
     *   { function: ghi, instruction_addr: ... }
     * ]
     * stacks: [ [0, 1, 2], [3, 4, 5] ]
     * samples: [
     *   { stack_id: 0, ... },
     *   { stack_id: 0, ... },
     *   { stack_id: 1, ... },
     *   { stack_id: 1, ... }
     * ]
     */
    _samplesStream = [[SentryJSONArrayStream alloc] initWithFileURL:temporaryFileURL()];
    _stacksStream = [[SentryJSONArrayStream alloc] initWithFileURL:temporaryFileURL()];
    const auto stacksCount = std::make_shared<std::uint64_t>(0);
    _framesStream = [[SentryJSONArrayStream alloc] initWithFileURL:temporaryFileURL()];
    const auto framesCount = std::make_shared<std::uint64_t>(0);
    const auto frameIndexLookupPtr = std::make_shared<std::unordered_map<std::uint64_t, std::uint64_t>>();
    _threadMetadata = std::make_shared<std::unordered_map<thread::TIDType, ThreadMetadata>>();
    _queueMetadata = std::make_shared<std::unordered_map<std::uint64_t, QueueMetadata>>();

    _startTimestamp = getAbsoluteTime();
    _startDate = [SentryCurrentDate date];

    SENTRY_LOG_DEBUG(@"Starting profiler %@ at system time %llu.", self, _startTimestamp);

    __weak const auto weakSelf = self;
    _profiler = std::make_shared<SamplingProfiler>(
        [=](auto &backtrace) {
            const auto strongSelf = weakSelf;
            if (strongSelf == nil) {
                SENTRY_LOG_WARN(
                    @"Profiler instance no longer exists, cannot process next sample.");
                return;
            }
            // The lock needs to be taken here again, because this is a callback that is
            // called from the sampling thread.
            std::lock_guard<std::mutex> l(strongSelf->_lock);
            processBacktrace(backtrace,
                             strongSelf->_threadMetadata,
                             strongSelf->_queueMetadata,
                             strongSelf->_samplesStream,
                             strongSelf->_stacksStream,
                             stacksCount,
                             strongSelf->_framesStream,
                             framesCount,
                             frameIndexLookupPtr,
                             strongSelf->_startTimestamp);
        },
        kSentryProfilerFrequencyHz);
    _profiler->startSampling();
}

- (void)addTransaction:(nonnull SentryTransaction *)transaction
{
    NSParameterAssert(transaction);
    if (transaction == nil) {
        SENTRY_LOG_WARN(@"Received nil transaction!");
        return;
    }

    SENTRY_LOG_DEBUG(@"Adding transaction %@ to list of profiled transactions for profiler %@.",
        transaction, self);
    if (_transactions == nil) {
        _transactions = [NSMutableArray<SentryTransaction *> array];
    }
    [_transactions addObject:transaction];
}

- (void)stop
{
    if (_profiler == nullptr || !_profiler->isSampling()) {
        return;
    }
    _profiler->stopSampling();
    NSLog(@"[INDRAGIE] STOP");
    {
        std::lock_guard<std::mutex> l(_lock);
        
        _endDate = [SentryCurrentDate date];
        SENTRY_LOG_DEBUG(@"Stopped profiler %@ at system time: %llu.", self, getAbsoluteTime());
        
        [_framesStream close];
        removeURL(_framesStream.fileURL);
        
        [_stacksStream close];
        removeURL(_stacksStream.fileURL);
        
        [_samplesStream close];
        removeURL(_samplesStream.fileURL);
    }
}

- (void)captureEnvelope
{
    const auto stream = [[SentryJSONObjectStream alloc] initWithFileURL:temporaryFileURL()];
    const auto endTimestamp = getAbsoluteTime();
    auto &writer = *stream.writer;
    {
        std::lock_guard<std::mutex> l(_lock);
        if (_profiler->numSamples() < 2) {
            SENTRY_LOG_DEBUG(@"No samples located in profile");
            [stream close];
            removeURL(stream.fileURL);
            return;
        }
        [_framesStream flush];
        [_stacksStream flush];
        [_samplesStream flush];
        {
            auto profileWriter = writer.nested_object("profile");
            profileWriter.write("frames", _framesStream.fileURL.fileSystemRepresentation, write_json_array_from_file());
            profileWriter.write("stacks", _stacksStream.fileURL.fileSystemRepresentation, write_json_array_from_file());
            profileWriter.write("samples", _samplesStream.fileURL.fileSystemRepresentation, write_json_array_from_file());
            {
                auto threadMetadataWriter = writer.nested_object("thread_metadata");
                for (auto &kv : *_threadMetadata) {
                    auto &m = kv.second;
                    auto threadWriter = threadMetadataWriter.nested_object(std::to_string(m.threadID).c_str());
                    if (!m.name.empty()) {
                        threadWriter.write("name", m.name);
                    }
                    if (m.priority > 0) {
                        threadWriter.write("priority", m.priority);
                    }
                    threadWriter.close();
                }
                threadMetadataWriter.close();
            }
            {
                auto queueMetadataWriter = writer.nested_object("queue_metadata");
                for (auto &kv : *_queueMetadata) {
                    auto &m = kv.second;
                    if (m.label == nullptr) { continue; }
                    auto queueWriter = queueMetadataWriter.nested_object(formatHex(m.address).c_str());
                    queueWriter.write("label", *m.label);
                    queueWriter.close();
                }
                queueMetadataWriter.close();
            }
            profileWriter.close();
        }
    }

    const auto profileID = [[SentryId alloc] init];
    const auto profileDuration = getDurationNs(_startTimestamp, endTimestamp);
    const auto bundle = NSBundle.mainBundle;
    
    writer.write("version", "1");
    writer.write("profile_id", profileID.sentryIdString);
    writer.write("duration_ns", [@(profileDuration) stringValue]);
    writer.write("truncation_reason", profilerTruncationReasonName(_truncationReason));
    writer.write("platform", _transactions.firstObject.platform);
    writer.write("environment", _hub.scope.environmentString ?: _hub.getClient.options.environment ?: kSentryDefaultEnvironment);
    writer.write("timestamp", [[SentryCurrentDate date] sentry_toIso8601String]);
    writer.write("release", [NSString stringWithFormat:@"%@ (%@)",
                             [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey],
                             [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]);
    
    {
        auto debugMetaWriter = writer.nested_object("debug_meta");
        auto imagesWriter = debugMetaWriter.nested_array("images");
        const auto debugMeta = [_debugImageProvider getDebugImages];
        for (SentryDebugMeta *debugImage in debugMeta) {
            auto imageWriter = imagesWriter.nested_object();
            imageWriter.write("type", "macho");
            imageWriter.write("debug_id", debugImage.uuid);
            imageWriter.write("code_file", debugImage.name);
            imageWriter.write("image_addr", debugImage.imageAddress);
            imageWriter.write("image_size", debugImage.imageSize);
            imageWriter.write("image_vmaddr", debugImage.imageVmAddress);
            imageWriter.close();
        }
        imagesWriter.close();
        debugMetaWriter.close();
    }
    {
        auto osWriter = writer.nested_object("os");
        osWriter.write("name", sentry_getOSName());
        osWriter.write("version", sentry_getOSVersion());
        osWriter.write("build_number", sentry_getOSBuildNumber());
        osWriter.close();
    }
    {
        const auto isSimulator = static_cast<bool>(sentry_isSimulatorBuild());
        auto deviceWriter = writer.nested_object("device");
        deviceWriter.write("architecture", sentry_getCPUArchitecture());
        deviceWriter.write("is_emulator", isSimulator);
        deviceWriter.write("locale", NSLocale.currentLocale.localeIdentifier);
        deviceWriter.write("manufacturer", "Apple");
        deviceWriter.write("model", isSimulator ? sentry_getSimulatorDeviceModel() : sentry_getDeviceModel());
        deviceWriter.close();
    }
//
//#    if SENTRY_HAS_UIKIT
//    auto relativeFrameTimestampsNs = [NSMutableArray array];
//    [_frameInfo.frameTimestamps enumerateObjectsUsingBlock:^(
//        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
//        const auto begin = (uint64_t)(obj[@"start_timestamp"].doubleValue * 1e9);
//        if (begin < _startTimestamp) {
//            return;
//        }
//        const auto end = (uint64_t)(obj[@"end_timestamp"].doubleValue * 1e9);
//        const auto relativeEnd = getDurationNs(_startTimestamp, end);
//        if (relativeEnd > profileDuration) {
//            SENTRY_LOG_DEBUG(@"The last slow/frozen frame extended past the end of the profile, "
//                             @"will not report it.");
//            return;
//        }
//        [relativeFrameTimestampsNs addObject:@{
//            @"start_timestamp_relative_ns" : @(getDurationNs(_startTimestamp, begin)),
//            @"end_timestamp_relative_ns" : @(relativeEnd),
//        }];
//    }];
//    profile[@"adverse_frame_render_timestamps"] = relativeFrameTimestampsNs;
//
//    relativeFrameTimestampsNs = [NSMutableArray array];
//    [_frameInfo.frameRateTimestamps enumerateObjectsUsingBlock:^(
//        NSDictionary<NSString *, NSNumber *> *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
//        const auto timestamp = (uint64_t)(obj[@"timestamp"].doubleValue * 1e9);
//        const auto refreshRate = obj[@"frame_rate"];
//        uint64_t relativeTimestamp = 0;
//        if (timestamp >= _startTimestamp) {
//            relativeTimestamp = getDurationNs(_startTimestamp, timestamp);
//        }
//        [relativeFrameTimestampsNs addObject:@{
//            @"start_timestamp_relative_ns" : @(relativeTimestamp),
//            @"frame_rate" : refreshRate,
//        }];
//    }];
//    profile[@"screen_frame_rates"] = relativeFrameTimestampsNs;
//#    endif // SENTRY_HAS_UIKIT
//
//    // populate info from all transactions that occurred while profiler was running
//    auto transactionsInfo = [NSMutableArray array];
//    SENTRY_LOG_DEBUG(@"Profile start timestamp: %@ absolute time: %llu", _startDate,
//        (unsigned long long)_startTimestamp);
//    SENTRY_LOG_DEBUG(@"Profile end timestamp: %@ absolute time: %llu", _endDate,
//        (unsigned long long)_endTimestamp);
//    for (SentryTransaction *transaction in _transactions) {
//        SENTRY_LOG_DEBUG(@"Transaction %@ start timestamp: %@", transaction.trace.context.traceId,
//            transaction.startTimestamp);
//        SENTRY_LOG_DEBUG(@"Transaction %@ end timestamp: %@", transaction.trace.context.traceId,
//            transaction.timestamp);
//        const auto relativeStart =
//            [NSString stringWithFormat:@"%llu",
//                      [transaction.startTimestamp compare:_startDate] == NSOrderedAscending
//                          ? 0
//                          : (unsigned long long)(
//                              [transaction.startTimestamp timeIntervalSinceDate:_startDate] * 1e9)];
//
//        NSString *relativeEnd;
//        if ([transaction.timestamp compare:_endDate] == NSOrderedDescending) {
//            relativeEnd = [NSString stringWithFormat:@"%llu", profileDuration];
//        } else {
//            const auto profileStartToTransactionEnd_ns =
//                [transaction.timestamp timeIntervalSinceDate:_startDate] * 1e9;
//            if (profileStartToTransactionEnd_ns < 0) {
//                SENTRY_LOG_DEBUG(@"Transaction %@ ended before the profiler started, won't "
//                                 @"associate it with this profile.",
//                    transaction.trace.context.traceId.sentryIdString);
//                continue;
//            } else {
//                relativeEnd = [NSString
//                    stringWithFormat:@"%llu", (unsigned long long)profileStartToTransactionEnd_ns];
//            }
//        }
//        [transactionsInfo addObject:@{
//            @"id" : transaction.eventId.sentryIdString,
//            @"trace_id" : transaction.trace.context.traceId.sentryIdString,
//            @"name" : transaction.transaction,
//            @"relative_start_ns" : relativeStart,
//            @"relative_end_ns" : relativeEnd,
//            @"active_thread_id" : [transaction.trace.transactionContext sentry_threadInfo].threadId
//        }];
//    }
//
//    if (transactionsInfo.count == 0) {
//        SENTRY_LOG_DEBUG(@"No transactions to associate with this profile, will not upload.");
//        return;
//    }
//    profile[@"transactions"] = transactionsInfo;

    
    [stream close];
    const auto JSONData = [NSData dataWithContentsOfURL:stream.fileURL];
    const auto header = [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeProfile
                                                                length:JSONData.length];
    const auto item = [[SentryEnvelopeItem alloc] initWithHeader:header data:JSONData];
    const auto envelopeHeader = [[SentryEnvelopeHeader alloc] initWithId:profileID];
    const auto envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader singleItem:item];

    SENTRY_LOG_DEBUG(@"[INDRAGIE] JSON PATH: %@", stream.fileURL);
    SENTRY_LOG_DEBUG(@"Capturing profile envelope.");
    [_hub captureEnvelope:envelope];
}

- (BOOL)isRunning
{
    if (_profiler == nullptr) {
        return NO;
    }
    return _profiler->isSampling();
}

static void removeURL(NSURL *fileURL) {
    if (fileURL == nil) { return; }
    [NSFileManager.defaultManager removeItemAtURL:fileURL error:nil];
}

@end

@implementation SentryJSONObjectStream {
    std::ofstream _stream;
    std::shared_ptr<minijson::object_writer> _writer;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    if (self = [super init]) {
        _fileURL = fileURL;
        _stream.open(_fileURL.fileSystemRepresentation);
        _stream.imbue(std::locale::classic());
        _writer = std::make_shared<minijson::object_writer>(_stream);
    }
    return self;
}

- (void)flush {
    _stream.flush();
}

- (void)close {
    if (_writer == nullptr) {
        return;
    }
    _writer->close();
    _stream.close();
    _writer = nullptr;
}

- (std::shared_ptr<minijson::object_writer>)writer {
    return _writer;
}

@end

@implementation SentryJSONArrayStream {
    std::ofstream _stream;
    std::shared_ptr<minijson::array_writer> _writer;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    if (self = [super init]) {
        _fileURL = fileURL;
        _stream.open(_fileURL.fileSystemRepresentation);
        _writer = std::make_shared<minijson::array_writer>(_stream);
    }
    return self;
}

- (void)flush {
    _stream.flush();
}

- (void)close {
    if (_writer == nullptr) {
        return;
    }
    _writer->close();
    _stream.close();
    _writer = nullptr;
}

- (std::shared_ptr<minijson::array_writer>)writer {
    return _writer;
}

@end

namespace minijson {
const char *safeCStrFromNSString(NSString *str) {
    if (str == nil) { return ""; }
    const char *cStr = [str cStringUsingEncoding:NSUTF8StringEncoding];
    if (cStr == NULL) { return ""; }
    return cStr;
}

template<>
struct default_value_writer<NSString *>
{
    void operator()(std::ostream& stream, NSString *str, __unused writer_configuration) const {
        default_value_writer<char*>()(stream, safeCStrFromNSString(str));
    }
};

template<>
struct default_value_writer<NSNumber *>
{
    void operator()(std::ostream& stream, NSNumber *num, __unused writer_configuration) const {
        default_value_writer<std::uint64_t>()(stream, num.unsignedLongLongValue);
    }
};

template<>
struct default_value_writer<ThreadMetadata>
{
    void operator()(std::ostream& stream, const ThreadMetadata &metadata, writer_configuration configuration) const {
        minijson::object_writer writer(stream, configuration);
        writer.write("name", metadata.name);
        writer.write("priority", metadata.priority);
        writer.close();
    }
};

template<>
struct default_value_writer<QueueMetadata>
{
    void operator()(std::ostream& stream, const QueueMetadata &metadata, writer_configuration configuration) const {
        minijson::object_writer writer(stream, configuration);
        if (metadata.label != nullptr) {
            writer.write("label", *metadata.label);
        }
        writer.close();
    }
};
}; // namespace minijson

#endif
