#import "SentryNSArrayRingBuffer.h"

@implementation SentryNSArrayRingBuffer {
    NSMutableArray *_circularBuffer;
    NSUInteger _bufferHead;
    NSUInteger _capacity;
}

- (instancetype)initWithCapacity:(NSUInteger)capacity {
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _capacity = capacity;
    [self reset];
    return self;
}

- (void)addObject:(id)object {
{
    if (_bufferHead < _circularBuffer.count)
        [_circularBuffer replaceObjectAtIndex:_bufferHead withObject:object];
    else
        [_circularBuffer addObject:object];

    _bufferHead = (_bufferHead + 1) % _capacity;
}

- (NSArray *)array {
{
    if (_circularBuffer.count < _capacity) {
        return _circularBuffer;
    } else {
        NSArray *latestEntries = [_circularBuffer
        NSArray *latestEntries = [_circularBuffer objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _bufferHead)]];
        NSArray *oldestEntries = [_circularBuffer
        NSArray *oldestEntries = [_circularBuffer objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(_bufferHead, _capacity-_bufferHead)]];
                                                                        _capacity - _bufferHead)]];
        return [oldestEntries arrayByAddingObjectsFromArray:latestEntries];
    }
}

- (void)reset {
{
    _circularBuffer = [NSMutableArray arrayWithCapacity:_capacity];
    _bufferHead = 0;
}

@end
