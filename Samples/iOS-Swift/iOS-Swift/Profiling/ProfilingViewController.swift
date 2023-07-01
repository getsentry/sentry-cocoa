//
//  ProfilingViewController.swift
//  iOS-Swift
//
//  Created by Andrew McKnight on 6/30/23.
//  Copyright © 2023 Sentry. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
class ProfilingViewController: UIViewController {

    @IBAction func startBenchmark(_ sender: Any) {
        SentryBenchmarking.start()
    }

    @IBAction func stopBenchmark(_ sender: Any) {
        print("[iOS-Swift] benchmarking results:\n" + SentryBenchmarking.stop().description)
        try! print("[iOS-Swift] machine info:\n" + SentryMachineInfo.cpuInfo().description)
    }

    @IBAction func mainThreadOnlyTest(_ sender: Any) {
        navigationController?.pushViewController(InefficientTableViewController(style: .insetGrouped), animated: true)

    }

    @IBAction func multithreadedTest(_ sender: Any) {
        navigationController?.pushViewController(EfficientTableViewController(style: .insetGrouped), animated: true)

    }
}
