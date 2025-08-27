import MachO
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import XCTest

// Import C functions from the SentryCrashBinaryImageCache
// These are test-only functions exposed from the implementation
@_silgen_name("sentry_setRegisterFuncForAddImage")
func sentry_setRegisterFuncForAddImage(_ addFunction: UnsafeMutableRawPointer?)

@_silgen_name("sentry_setRegisterFuncForRemoveImage") 
func sentry_setRegisterFuncForRemoveImage(_ removeFunction: UnsafeMutableRawPointer?)

@_silgen_name("sentry_resetFuncForAddRemoveImage")
func sentry_resetFuncForAddRemoveImage()

@_silgen_name("sentry_setFuncForBeforeAdd")
func sentry_setFuncForBeforeAdd(_ callback: (@convention(c) () -> Void)?)

@_silgen_name("sentrycrashbic_iterateOverImages")
func sentrycrashbic_iterateOverImages(_ callback: (@convention(c) (UnsafeMutablePointer<SentryCrashBinaryImage>, UnsafeMutableRawPointer?) -> Void)?, _ context: UnsafeMutableRawPointer?)

@_silgen_name("sentrycrashdl_clearDyld")
func sentrycrashdl_clearDyld()

// Global variables to mirror the Objective-C implementation
private var addBinaryImageFunc: (@convention(c) (UnsafePointer<mach_header>?, Int) -> Void)?
private var removeBinaryImageFunc: (@convention(c) (UnsafePointer<mach_header>?, Int) -> Void)?
private var machHeadersTestCache: [UnsafeRawPointer] = []
private var machHeadersExpectArray: [UnsafeRawPointer] = []

// Semaphores for testing parallel operations
private var delaySemaphore: DispatchSemaphore?
private var delayCalled: DispatchSemaphore?

// C callback functions
private let sentryRegisterFuncForAddImage: @convention(c) ((@convention(c) (UnsafePointer<mach_header>?, Int) -> Void)?) -> Void =
{ function in
    addBinaryImageFunc = function
    
    if !machHeadersExpectArray.isEmpty {
        // Skip first item which is dyld and already included when starting the cache
        for i in 1..<machHeadersExpectArray.count {
            let header = machHeadersExpectArray[i].assumingMemoryBound(to: mach_header.self)
            function?(header, 0)
        }
    }
}

private let sentryRegisterFuncForRemoveImage: @convention(c) ((@convention(c) (UnsafePointer<mach_header>?, Int) -> Void)?) -> Void = { function in
    removeBinaryImageFunc = function
}

private let cacheMachHeaders: @convention(c) (UnsafePointer<mach_header>?, Int) -> Void = { mh, _ in
    guard let mh = mh else { return }
    machHeadersTestCache.append(UnsafeRawPointer(mh))
}

private let countNumberOfImagesInCache: @convention(c) (UnsafeMutablePointer<SentryCrashBinaryImage>, UnsafeMutableRawPointer?) -> Void = { _, context in
    guard let context = context else { return }
    let counter = context.assumingMemoryBound(to: Int.self)
    counter.pointee += 1
}

private let addBinaryImageToArray: @convention(c) (UnsafeMutablePointer<SentryCrashBinaryImage>, UnsafeMutableRawPointer?) -> Void = { image, context in
    guard let context = context else { return }
    let array = Unmanaged<NSMutableArray>.fromOpaque(context).takeUnretainedValue()
    array.add(NSValue(pointer: image))
}

private let delayAddBinaryImage: @convention(c) () -> Void = {
    if let delayCalled = delayCalled {
        delayCalled.signal()
    }
    if let delaySemaphore = delaySemaphore {
        delaySemaphore.wait()
    }
}

class SentryCrashBinaryImageCacheTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        // Create a test cache of actual binary images to be used during tests
        machHeadersTestCache = []
        
        // Manually include dyld
        sentrycrashdl_initialize()
        if let dyldHeader = sentryDyldHeader {
            machHeadersTestCache.append(UnsafeRawPointer(dyldHeader))
        }
        _dyld_register_func_for_add_image(cacheMachHeaders)
    }
    
    override func setUp() {
        super.setUp()
        sentry_setRegisterFuncForAddImage(unsafeBitCast(sentryRegisterFuncForAddImage, to: UnsafeMutableRawPointer.self))
        sentry_setRegisterFuncForRemoveImage(unsafeBitCast(sentryRegisterFuncForRemoveImage, to: UnsafeMutableRawPointer.self))
        
        // Copy the first 5 images from the temporary list
        // 5 is a magic number from the original implementation
        let endIndex = min(5, machHeadersTestCache.count)
        machHeadersExpectArray = Array(machHeadersTestCache[0..<endIndex])
    }
    
    override func tearDown() {
        sentrycrashdl_clearDyld()
        sentry_resetFuncForAddRemoveImage()
        sentrycrashbic_stopCache()
        sentry_setFuncForBeforeAdd(nil)
        SentryDependencyContainer.reset()
        super.tearDown()
    }
    
    func testStartCache() {
        SentryCrashWrapper.sharedInstance().startBinaryImageCache()
        assertBinaryImageCacheLength(5)
    }
    
    func testStartCacheTwice() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
    }
    
    func testStopCache() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        sentrycrashbic_stopCache()
        assertBinaryImageCacheLength(0)
    }
    
    func testStopCacheTwice() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        sentrycrashbic_stopCache()
        assertBinaryImageCacheLength(0)
        sentrycrashbic_stopCache()
        assertBinaryImageCacheLength(0)
    }
    
    func testAddNewImage() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        
        if machHeadersTestCache.count > 5 {
            let header = machHeadersTestCache[5].assumingMemoryBound(to: mach_header.self)
            addBinaryImageFunc?(header, 0)
            machHeadersExpectArray = Array(machHeadersTestCache[0..<6])
            assertBinaryImageCacheLength(6)
            assertCachedBinaryImages()
        }
        
        if machHeadersTestCache.count > 6 {
            let header = machHeadersTestCache[6].assumingMemoryBound(to: mach_header.self)
            addBinaryImageFunc?(header, 0)
            machHeadersExpectArray = Array(machHeadersTestCache[0..<7])
            assertBinaryImageCacheLength(7)
            assertCachedBinaryImages()
        }
    }
    
    func testAddInvalidHeader() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        
        addBinaryImageFunc?(nil, 0)
        assertBinaryImageCacheLength(5)
    }
    
    func testAddNewImageAfterStopping() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        
        sentrycrashbic_stopCache()
        if machHeadersTestCache.count > 6 {
            let header = machHeadersTestCache[6].assumingMemoryBound(to: mach_header.self)
            addBinaryImageFunc?(header, 0)
        }
        assertBinaryImageCacheLength(0)
    }
    
    func testRemoveImageFromTail() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        
        let header4 = machHeadersExpectArray[4].assumingMemoryBound(to: mach_header.self)
        removeBinaryImageFunc?(header4, 0)
        assertBinaryImageCacheLength(4)
        assertCachedBinaryImages()
        
        let header3 = machHeadersExpectArray[3].assumingMemoryBound(to: mach_header.self)
        removeBinaryImageFunc?(header3, 0)
        assertBinaryImageCacheLength(3)
        assertCachedBinaryImages()
    }
    
    func testRemoveImageFromBeginning() {
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        
        let header0 = machHeadersExpectArray[0].assumingMemoryBound(to: mach_header.self)
        removeBinaryImageFunc?(header0, 0)
        assertBinaryImageCacheLength(4)
        machHeadersExpectArray.removeFirst()
        assertCachedBinaryImages()
        
        let newHeader0 = machHeadersExpectArray[0].assumingMemoryBound(to: mach_header.self)
        removeBinaryImageFunc?(newHeader0, 0)
        assertBinaryImageCacheLength(3)
        machHeadersExpectArray.removeFirst()
        assertCachedBinaryImages()
    }
    
    func testRemoveImageAddAgain() {
        // Use index 1 since we can't dynamically insert dyld image (`dladdr` returns null)
        let indexToRemove = 1
        
        sentrycrashbic_startCache()
        assertBinaryImageCacheLength(5)
        
        let headerToRemove = machHeadersExpectArray[indexToRemove].assumingMemoryBound(to: mach_header.self)
        removeBinaryImageFunc?(headerToRemove, 0)
        assertBinaryImageCacheLength(4)
        
        let removeItem = machHeadersExpectArray[indexToRemove]
        machHeadersExpectArray.remove(at: indexToRemove)
        assertCachedBinaryImages()
        
        addBinaryImageFunc?(removeItem.assumingMemoryBound(to: mach_header.self), 0)
        assertBinaryImageCacheLength(5)
        machHeadersExpectArray.insert(removeItem, at: 4)
        assertCachedBinaryImages()
    }
    
    func testAddBinaryImageInParallel() {
        sentrycrashbic_startCache()
        let queue = DispatchQueue.global(qos: .default)
        
        // Guard against underflow when machHeadersTestCache.count < 5
        let taskCount = machHeadersTestCache.count - 5
        guard taskCount > 0 else {
            XCTFail("Expected a positive task count, but got \(taskCount)")
            return
        }
        
        let expectation = self.expectation(description: "Add binary images in parallel")
        expectation.expectedFulfillmentCount = taskCount
        
        for i in 5..<machHeadersTestCache.count {
            queue.async {
                let header = machHeadersTestCache[i].assumingMemoryBound(to: mach_header.self)
                addBinaryImageFunc?(header, 0)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
        assertBinaryImageCacheLength(machHeadersTestCache.count)
    }
    
    func testCloseCacheWhileAdding() {
        sentrycrashbic_startCache()
        sentry_setFuncForBeforeAdd(delayAddBinaryImage)
        delaySemaphore = DispatchSemaphore(value: 0)
        delayCalled = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .default).async {
            if machHeadersTestCache.count > 6 {
                let header = machHeadersTestCache[6].assumingMemoryBound(to: mach_header.self)
                addBinaryImageFunc?(header, 0)
            }
        }
        
        let result = delayCalled?.wait(timeout: .now() + 5)
        sentrycrashbic_stopCache()
        delaySemaphore?.signal()
        assertBinaryImageCacheLength(0)
        XCTAssertEqual(result, .success)
    }
    
    // Adding a SentryBinaryImageCache test inside SentryCrashBinaryImageCache to test integration 
    // The test is in Swift because of some classes are not available to Objective-C
    func testSentryBinaryImageCacheIntegration() {
        sentrycrashbic_startCache()
        
        let imageCache = SentryDependencyContainer.sharedInstance().binaryImageCache
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        imageCache.start(false, dispatchQueueWrapper: dispatchQueueWrapper)
        // By calling start, SentryBinaryImageCache will register a callback with
        // `SentryCrashBinaryImageCache` that should be called for every image already cached.
        XCTAssertEqual(5, imageCache.cache?.count ?? 0)
        
        if machHeadersTestCache.count > 5 {
            let header = machHeadersTestCache[5].assumingMemoryBound(to: mach_header.self)
            addBinaryImageFunc?(header, 0)
            XCTAssertEqual(6, imageCache.cache?.count ?? 0)
        }
        
        if machHeadersExpectArray.count > 1 {
            let header1 = machHeadersExpectArray[1].assumingMemoryBound(to: mach_header.self)
            removeBinaryImageFunc?(header1, 0)
        }
        
        if machHeadersExpectArray.count > 2 {
            let header2 = machHeadersExpectArray[2].assumingMemoryBound(to: mach_header.self)
            removeBinaryImageFunc?(header2, 0)
        }
        
        XCTAssertEqual(4, imageCache.cache?.count ?? 0)
        imageCache.stop()
        
        if machHeadersTestCache.count > 6 {
            let header = machHeadersTestCache[6].assumingMemoryBound(to: mach_header.self)
            addBinaryImageFunc?(header, 0)
        }
        XCTAssertNil(imageCache.cache)
    }
    
    // MARK: - Helper Methods
    
    private func assertBinaryImageCacheLength(_ expected: Int) {
        var counter = 0
        withUnsafeMutablePointer(to: &counter) { counterPtr in
            sentrycrashbic_iterateOverImages(countNumberOfImagesInCache, UnsafeMutableRawPointer(counterPtr))
        }
        XCTAssertEqual(counter, expected)
    }
    
    private func assertCachedBinaryImages() {
        let cached = binaryImageCacheToArray()
        for i in 0..<cached.count {
            guard let binaryImageValue = cached[i] as? NSValue else { continue }
            let binaryImage = binaryImageValue.pointerValue!.assumingMemoryBound(to: SentryCrashBinaryImage.self)
            let header = machHeadersExpectArray[i]
            XCTAssertEqual(binaryImage.pointee.address, UInt64(bitPattern: Int64(Int(bitPattern: header))))
        }
    }
    
    private func binaryImageCacheToArray() -> NSArray {
        let result = NSMutableArray()
        let unmanagedArray = Unmanaged.passUnretained(result)
        sentrycrashbic_iterateOverImages(addBinaryImageToArray, unmanagedArray.toOpaque())
        return result
    }
}
