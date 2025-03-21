import Sentry
import UIKit

class ProfilingViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var workThreadLabel: UILabel!
    @IBOutlet weak var workIntensityFactorLabel: UILabel!
    
    @IBOutlet weak var workThreadSlider: UISlider!
    @IBOutlet weak var workIntervalSlider: UISlider!
    
    @IBOutlet weak var maxThreadsTextField: UITextField!
    @IBOutlet weak var minThreadsTextField: UITextField!
    @IBOutlet weak var minWorkIntensityTextField: UITextField!
    @IBOutlet weak var maxWorkIntensityTextField: UITextField!
    @IBOutlet weak var valueTextField: UITextField!
    
    @IBOutlet weak var launchProfilingMarkerFileCheckButton: UIButton!
    @IBOutlet weak var profilingUITestDataMarshalingTextField: UITextField!
    @IBOutlet weak var profilingUITestDataMarshalingStatus: UILabel!
        
    @IBOutlet weak var dsnView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        minWorkIntensityTextField.text = String(defaultLongestIntervalMicros)
        maxWorkIntensityTextField.text = String(1)
        minThreadsTextField.text = String(4)
        maxThreadsTextField.text = String(50)
        [maxThreadsTextField, minThreadsTextField, minWorkIntensityTextField, maxWorkIntensityTextField].forEach {
            $0?.delegate = self
        }
        profilingUITestDataMarshalingTextField.accessibilityLabel = "io.sentry.ui-tests.profile-marshaling-text-field"
        launchProfilingMarkerFileCheckButton.accessibilityLabel = "io.sentry.ui-tests.app-launch-profile-marker-file-button"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
        
        addDSNDisplay(self, vcview: dsnView)
    }
    
    @IBAction func startBenchmark(_ sender: UIButton) {
        highlightButton(sender)
        SentryBenchmarking.startBenchmark()
    }
    
    @IBAction func stopBenchmark(_ sender: UIButton) {
        highlightButton(sender)
        guard let value = SentryBenchmarking.stopBenchmark() else {
            let alert = UIAlertController(title: "Benchmark Error", message: "No benchmark result available.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: false)
            print("[iOS-Swift] [debug] [ProfilingViewController] no benchmark result returned")
            return
        }
        valueTextField.isHidden = false
        valueTextField.text = value
        print("[iOS-Swift] [debug] [ProfilingViewController] benchmarking results:\n\(value)")
    }
    
    @IBAction func startCPUWork(_ sender: UIButton) {
        highlightButton(sender)
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
    
    @IBAction func endCPUWork(_ sender: UIButton) {
        highlightButton(sender)
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
    
    @IBAction func checkLaunchProfilingMarkerFile(_ sender: Any) {
        let launchProfileMarkerPath = ((NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("io.sentry") as NSString).appendingPathComponent("profileLaunch")
        if FileManager.default.fileExists(atPath: launchProfileMarkerPath) {
            profilingUITestDataMarshalingTextField.text = "<exists>"
        } else {
            profilingUITestDataMarshalingTextField.text = "<missing>"
        }
    }
    
    @IBAction func startContinuousProfiler(_ sender: Any) {
        SentrySDK.startProfiler()
    }
    
    @IBAction func stopContinuousProfiler(_ sender: Any) {
        SentrySDK.stopProfiler()
    }
    
    @IBAction func viewLastProfile(_ sender: Any) {
        profilingUITestDataMarshalingTextField.text = "<fetching...>"
        withProfile(continuous: false) { file in
            handleContents(file: file)
        }
    }
    
    @IBAction func viewFirstContinuousProfileChunk(_ sender: Any) {
        profilingUITestDataMarshalingTextField.text = "<fetching...>"
        withProfile(continuous: true) { file in
            handleContents(file: file)
        }
    }
        
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
    
    private func withProfile(continuous: Bool, block: (URL?) -> Void) {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let fm = FileManager.default
        let dir = "\(cachesDirectory)/io.sentry/" + (continuous ? "continuous-profiles" : "trace-profiles")
        let count = try! fm.contentsOfDirectory(atPath: dir).count
        //swiftlint:disable empty_count
        guard continuous || count > 0 else {
            //swiftlint:enable empty_count
            profilingUITestDataMarshalingTextField.text = "<missing>"
            return
        }
        let fileName = "profile\(continuous ? 0 : count - 1)"
        let fullPath = "\(dir)/\(fileName)"
        
        if fm.fileExists(atPath: fullPath) {
            let url = NSURL.fileURL(withPath: fullPath)
            block(url)
            do {
                try fm.removeItem(atPath: fullPath)
            } catch {
                SentrySDK.capture(error: error)
            }
            return
        }
        
        block(nil)
    }
    
    private func handleContents(file: URL?) {
        guard let file = file else {
            profilingUITestDataMarshalingTextField.text = "<missing>"
            profilingUITestDataMarshalingStatus.text = "❌"
            return
        }
        
        do {
            let data = try Data(contentsOf: file)
            let contents = data.base64EncodedString()
            print("[iOS-Swift] [debug] [ProfilingViewController] contents of file at \(file): \(String(describing: String(data: data, encoding: .utf8)))")
            profilingUITestDataMarshalingTextField.text = contents
            profilingUITestDataMarshalingStatus.text = "✅"
        } catch {
            SentrySDK.capture(error: error)
            profilingUITestDataMarshalingTextField.text = "<empty>"
            profilingUITestDataMarshalingStatus.text = "❌"
        }
    }
    
    func _adjustWorkThreadsToCurrentRequirement() {
        let maxThreads = (maxThreadsTextField.text! as NSString).integerValue
        let minThreads = (minThreadsTextField.text! as NSString).integerValue
        let requiredThreads = _projectedRange(factor: workThreadSlider.value, min: minThreads, max: maxThreads)
        let diff = requiredThreads - cpuWorkthreads.count
        if diff == 0 {
            return
        } else if diff > 0 {
            for _ in 0 ..< diff {
                let thread = WorkThread()
                thread.qualityOfService = .userInteractive
                cpuWorkthreads.insert(thread)
                thread.start()
            }
        } else {
            let absDiff = abs(diff)
            for _ in 0 ..< absDiff {
                let thread = cpuWorkthreads.removeFirst()
                thread.cancel()
            }
        }
    }

    private func _adjustWorkIntervalToCurrentRequirements() {
        let minInterval = (minWorkIntensityTextField.text! as NSString).integerValue
        let maxInterval = (maxWorkIntensityTextField.text! as NSString).integerValue
        workIntervalMicros = UInt32(_projectedRange(factor: workIntervalSlider.value, min: minInterval, max: maxInterval))
    }
}
