//
//  ProfilingViewController.swift
//  iOS-Swift
//
//  Created by Andrew McKnight on 6/30/23.
//  Copyright © 2023 Sentry. All rights reserved.
//

import CoreLocation
import UIKit

@available(iOS 13.0, *)
class ProfilingViewController: UIViewController {

    @IBAction func startBenchmark(_ sender: Any) {
        SentryBenchmarking.shared().start()
    }

    @IBAction func stopBenchmark(_ sender: Any) {
        print("[iOS-Swift] benchmarking results:\n" + SentryBenchmarking.shared().stop().description)
        try! print("[iOS-Swift] machine info:\n" + SentryMachineInfo.cpuInfo().description)
    }

    @IBAction func startGPSUpdates(_ sender: Any) {
        CLLocationManager().startUpdatingLocation()
    }

    @IBAction func endGPSUpdates(_ sender: Any) {
        CLLocationManager().stopUpdatingLocation()
    }

    var shouldDrainBattery = false
    @IBAction func drainBattery() {
        shouldDrainBattery = true
        for _ in 0..<ProcessInfo.processInfo.processorCount {
            DispatchQueue.global(qos: .userInitiated).async {
                self._drainBattery()
            }
        }
//        _drainBattery()
    }

    @IBAction func endDrainBattery() {
        shouldDrainBattery = false
    }

    func _drainBattery() {
        while true {
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

            if !shouldDrainBattery {
                break
            }
        }
    }
}
