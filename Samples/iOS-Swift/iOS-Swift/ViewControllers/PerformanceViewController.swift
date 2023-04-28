import Sentry
import UIKit

class PerformanceViewController: UIViewController {
    private let valueTextField = UITextField(frame: .zero)

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        valueTextField.accessibilityLabel = "io.sentry.benchmark.value-marshaling-text-field"
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(valueTextField)
        NSLayoutConstraint.activate([
            valueTextField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            valueTextField.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -20)
        ])
        valueTextField.isHidden = true

        view.backgroundColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTest()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        transaction?.finish()
    }

    // refresh rate of 60 hz is 0.0167
    // 120 hz is 0.0083
    // 240 hz is 0.004167
    private let interval = 0.00000005

    private var timer: Timer?
    private let iterations = 5_000_000
    private let range = 1..<Double.greatestFiniteMagnitude
    private var transaction: Span?
}

private extension PerformanceViewController {
    func doWork(withNumber a: Double) -> Double {
        var b: Double
        if arc4random() % 2 == 0 {
            b = fmod(a, Double.random(in: range))
        } else {
            b = fmod(Double.random(in: range), a)
        }
        if b == 0 {
            b = Double.random(in: range)
        }
        return b
    }

    @objc func doRandomWork() {
        var a = doWork(withNumber: Double.random(in: range))
        for _ in 0..<iterations {
            a = doWork(withNumber: a)
        }
    }

    func startTest() {
        SentrySDK.configureScope {
            $0.setTag(value: "performance-benchmark", key: "uitest-type")
        }
        transaction = SentrySDK.startTransaction(name: "io.sentry.benchmark.transaction", operation: "crunch-numbers")
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(doRandomWork), userInfo: nil, repeats: true)
        SentryBenchmarking.startSampledBenchmark()

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            self.stopTest()
        }
    }

    func stopTest() {
        defer {
            timer?.invalidate()
            transaction?.finish()
            transaction = nil
        }

        guard let value = SentryBenchmarking.stopSampledBenchmark() else {
            SentrySDK.capture(error: NSError(domain: "io.sentry.benchmark.error", code: 1, userInfo: ["description": "Only one CPU sample was taken, can't calculate benchmark deltas."]))
            valueTextField.text = "nil"
            return
        }

        valueTextField.isHidden = false
        valueTextField.text = "\(value)"

        SentrySDK.configureScope {
            $0.setContext(value: [
                "percent-usage": value,
                "device-model": UIDevice.current.model,
                "device-system-name": UIDevice.current.systemName,
                "device-system-version": UIDevice.current.systemVersion
            ], key: "performance-benchmark-results")
        }
    }
}
