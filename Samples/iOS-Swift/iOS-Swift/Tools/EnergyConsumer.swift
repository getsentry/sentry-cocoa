import simd
final class BatteryConsumer {
  
  init(qos: DispatchQoS) {
    queue = DispatchQueue(
        label: "com.sentry.sample.BatteryConsumer",
        qos: qos,
        attributes: .concurrent)
  }

  private let queue: DispatchQueue
  private var workItem: DispatchWorkItem?
  private let lock = NSLock()
  private var running = false

  @available(iOS 15.0, *)
  func start() {
    lock.lock()
    defer { lock.unlock() }
    guard !running else { return }
    running = true
    
    let item = DispatchWorkItem { [weak self] in
      
      var accumulator = simd_double4(0, 0, 0, 0)
      
      while self?.isRunning ?? false {
        // Do a batch of meaningless but FP-heavy math.
        for i in 1...16_384 {
          let v = simd_double4(Double(i), Double(i) + 1,
                               Double(i) + 2, Double(i) + 3)
          accumulator += sin(v) * cos(v)
        }
        
        // Touch memory so the optimizer can’t remove the loop.
        // This makes the loop both CPU- and memory-intensive.
        if accumulator.x.isInfinite { print(accumulator) }
      }
    }
    
    workItem = item
    queue.async(execute: item)
  }
  
  func stop() {
    lock.lock()
    running = false
    lock.unlock()
    workItem?.cancel()
    workItem = nil
  }
  
  private var isRunning: Bool {
    lock.lock()
    defer { lock.unlock() }
    return running
  }
}
