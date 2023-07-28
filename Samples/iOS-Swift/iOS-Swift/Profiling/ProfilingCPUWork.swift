//
//  ProfilingCPUWork.swift
//  iOS-Swift
//
//  Created by Andrew McKnight on 7/28/23.
//  Copyright © 2023 Sentry. All rights reserved.
//

import UIKit

// the following threads/interval defaults achieve about 100% (out of 600%) CPU usage on an iPhone 14 Pro
let defaultMinThreadsPerCoreRatio = 3
let defaultLongestIntervalMicros: useconds_t = 60

var workIntervalMicros: useconds_t = defaultLongestIntervalMicros

let cpuInfo = try! SentryMachineInfo.cpuInfo()

func _doSomeWork() {
    var results = [Double]()
    let a = Double(max(UInt64(arc4random()), 1))
    let b = Double(max(UInt64(arc4random()), 1))
    let c = a + b
    let d = max(a > b ? a - b : b - a, 1)
    let e = c / d
    let f = d / c
    results.append(contentsOf: [a, b, c, d, e, f].sorted().shuffled().sorted(by: { a, b in
        if UInt64(a) % 2 == 0 && UInt64(b) % 3 == 0 {
            return a < b
        } else if UInt64(a) % 3 == 0 || UInt64(a) % 5 == 0 {
            return b < a
        } else {
            return c < d
        }
    }))
}

class WorkThread: Thread {
    override func main() {
        while true {
            if isCancelled { break }
            _doSomeWork()
            usleep(workIntervalMicros)
        }
    }
}

var cpuWorkthreads = Set<Thread>()
var shouldDrainBattery = false

func _projectedRange(factor: Float, min: Int, max: Int) -> Int {
    Int(factor * Float(max - min)) + min
}

func _drainBattery() {
    while true {
        _doSomeWork()

        if !shouldDrainBattery {
            break
        }
    }
}

class ProfilingCPUWork: NSObject {

}
