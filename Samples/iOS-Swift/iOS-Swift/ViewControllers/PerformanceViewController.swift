import Sentry
import UIKit

class PerformanceViewController: UIViewController {
    private let startTestButton = UIButton(type: .custom)
    private let stopTestButton = UIButton(type: .custom)
    private let valueTextField = UITextField(frame: .zero)

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        startTestButton.addTarget(self, action: #selector(startTest), for: .touchUpInside)
        startTestButton.setTitle("Start test", for: .normal)

        stopTestButton.addTarget(self, action: #selector(stopTest), for: .touchUpInside)
        stopTestButton.setTitle("Stop test", for: .normal)

        let buttons = [
            startTestButton,
            stopTestButton
        ]
        buttons.forEach {
            $0.setTitleColor(.black, for: .normal)
        }
        valueTextField.accessibilityLabel = "io.sentry.benchmark.value-marshaling-text-field"
        let stack = UIStackView(arrangedSubviews: buttons + [valueTextField])
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor)
            ])
        }

        view.backgroundColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        transaction?.finish()
    }

    // refresh rate of 60 hz is 0.0167
    // 120 hz is 0.0083
    // 240 hz is 0.004167
    private let interval = 0.000_000_05

    private var timer: Timer?
    private let iterations = 5_000_000
    private let range = 1..<Double.greatestFiniteMagnitude
    private var transaction: Span?

    private func doWork(withNumber a: Double) -> Double {
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

    @objc func startTest() {
        SentrySDK.configureScope {
            $0.setTag(value: "performance-benchmark", key: "uitest-type")
        }
        transaction = SentrySDK.startTransaction(name: "io.sentry.benchmark.transaction", operation: "crunch-numbers")
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(doRandomWork), userInfo: nil, repeats: true)
        SentryBenchmarking.startBenchmarkProfile()
    }

    @objc func stopTest() {
        let value = SentryBenchmarking.retrieveBenchmarks()
        
        defer {
            timer?.invalidate()
            transaction?.finish()
            transaction = nil
            valueTextField.text = "\(value)"
        }

        guard value >= 0 else {
            SentrySDK.capture(error: NSError(domain: "io.sentry.benchmark.error", code: 1, userInfo: ["description": "Only one CPU sample was taken, can't calculate benchmark deltas."]))
            return
        }

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
