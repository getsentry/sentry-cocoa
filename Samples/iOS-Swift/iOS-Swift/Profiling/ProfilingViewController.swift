//
//  ProfilingViewController.swift
//  iOS-Swift
//
//  Created by Andrew McKnight on 6/30/23.
//  Copyright © 2023 Sentry. All rights reserved.
//

import CoreBluetooth
import CoreLocation
import UIKit

@available(iOS 13.0, *)
class ProfilingViewController: UIViewController {

    @IBOutlet weak var workThreadLabel: UILabel!
    @IBOutlet weak var workIntensityFactorLabel: UILabel!
    @IBOutlet weak var minWorkIntensityLabel: UILabel!

    @IBOutlet weak var workThreadSlider: UISlider!
    @IBOutlet weak var workIntervalSlider: UISlider!

    @IBOutlet weak var maxThreadsTextField: UITextField!
    @IBOutlet weak var minThreadsTextField: UITextField!
    @IBOutlet weak var minWorkIntensityTextField: UITextField!
    @IBOutlet weak var maxWorkIntensityTextField: UITextField!

    let centralManager = CBCentralManager()
    let peripheralManager = CBPeripheralManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        minWorkIntensityTextField.text = String(defaultLongestIntervalMicros)
        maxWorkIntensityTextField.text = String(1)
        minThreadsTextField.text = String(cpuInfo.enabledLogicalCores * 3)
        maxThreadsTextField.text = String(cpuInfo.enabledLogicalCores * 10)
    }

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

    @IBAction func startHeadingUpdates(_ sender: Any) {
        CLLocationManager().startUpdatingHeading()
    }

    @IBAction func endHeadingUpdates(_ sender: Any) {
        CLLocationManager().stopUpdatingHeading()
    }

    var networkScanner: ProfilingNetworkScanner?
    @IBAction func startNetworkWork(_ sender: Any) {
        guard networkScanner == nil else { return }
        networkScanner = ProfilingNetworkScanner()
        networkScanner?.start()
    }

    @IBAction func endNetworkWork(_ sender: Any) {
        networkScanner?.end()
    }

    @IBAction func startBluetoothScan(_ sender: Any) {
        centralManager.scanForPeripherals(withServices: nil)
    }

    @IBAction func endBluetoothScan(_ sender: Any) {
        centralManager.stopScan()
    }

    @IBAction func startBluetoothAdvertise(_ sender: Any) {
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [UUID(), UUID(), UUID()]])
    }

    @IBAction func endBluetoothAdvertise(_ sender: Any) {
        peripheralManager.stopAdvertising()
    }

    @IBAction func drainBattery() {
        shouldDrainBattery = true
        for _ in 0..<ProcessInfo.processInfo.processorCount {
            DispatchQueue.global(qos: .userInitiated).async {
                _drainBattery()
            }
        }
    }

    @IBAction func endDrainBattery() {
        shouldDrainBattery = false
    }

    @IBAction func startCPUWork() {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func minWorkThreadCountChanged(_ sender: Any) {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func workThreadSliderChanged(_ sender: Any) {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func maxWorkThreadCountChanged(_ sender: Any) {
        _adjustWorkThreadsToCurrentRequirement()
    }

    @IBAction func endCPUWork() {
        cpuWorkthreads.forEach { $0.cancel() }
        cpuWorkthreads.removeAll()
    }

    @IBAction func minWorkIntervalChanged(_ sender: Any) {
        _adjustWorkIntervalToCurrentRequirements()
    }

    @IBAction func workIntensityChanged(_ sender: UISlider) {
        _adjustWorkIntervalToCurrentRequirements()
    }

    @IBAction func maxWorkIntervalChanged(_ sender: Any) {
        _adjustWorkIntervalToCurrentRequirements()
    }

    @IBAction func bgBrightnessChanged(_ sender: UISlider) {
        view.backgroundColor = .init(white: CGFloat(sender.value), alpha: 1)
    }

    // MARK: Private

    func _adjustWorkThreadsToCurrentRequirement() {
        let maxThreads = (maxThreadsTextField.text! as NSString).integerValue
        let minThreads = (minThreadsTextField.text! as NSString).integerValue
        let requiredThreads = _projectedRange(factor: workThreadSlider.value, min: minThreads, max: maxThreads)
        let diff = requiredThreads - cpuWorkthreads.count
        if diff == 0 {
            return
        } else if diff > 0 {
    //            print("creating \(diff) threads")
            for _ in 0 ..< diff {
                let thread = WorkThread()
                thread.qualityOfService = .userInteractive
                cpuWorkthreads.insert(thread)
                thread.start()
            }
        } else {
            let absDiff = abs(diff)
    //            print("removing \(absDiff) threads")
            for _ in 0 ..< absDiff {
                let thread = cpuWorkthreads.removeFirst()
                thread.cancel()
            }
        }
    }

    func _adjustWorkIntervalToCurrentRequirements() {
        let minInterval = (minWorkIntensityTextField.text! as NSString).integerValue
        let maxInterval = (maxWorkIntensityTextField.text! as NSString).integerValue
        workIntervalMicros = UInt32(_projectedRange(factor: workIntervalSlider.value, min: minInterval, max: maxInterval))
    //        print("workIntervalMicros: \(workIntervalMicros)")
    }
}
