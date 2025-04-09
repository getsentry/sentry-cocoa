import Sentry
import UIKit

class ProfilingViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var launchProfilingMarkerFileCheckButton: UIButton!
    @IBOutlet weak var profilingUITestDataMarshalingTextField: UITextField!
    @IBOutlet weak var profilingUITestDataMarshalingStatus: UILabel!

    @IBOutlet weak var sampleRateField: UITextField!
    @IBOutlet weak var tracesSampleRateField: UITextField!
    @IBOutlet weak var tracesSampleRateSwitch: UISwitch!
    @IBOutlet weak var profileAppStartsSwitch: UISwitch!

    @IBOutlet weak var profilesSampleRateSwitch: UISwitch!
    @IBOutlet weak var profilingV2Stack: UIStackView!
    @IBOutlet weak var traceLifecycleSwitch: UISwitch!
    @IBOutlet weak var sessionSampleRateField: UITextField!

    @IBOutlet weak var dsnView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        addDSNDisplay(self, vcview: dsnView)
        optionsConfiguration()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
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

    @IBAction func sampleRateEdited(_ sender: UITextField) {
        SentrySDKOverrides.Profiling.sampleRate = getSampleRateOverride(field: sender)
    }

    @IBAction func tracesSampleRateEdited(_ sender: UITextField) {
        SentrySDKOverrides.Tracing.sampleRate = getSampleRateOverride(field: sender)
    }

    @IBAction func profileAppStartsToggled(_ sender: UISwitch) {
        SentrySDKOverrides.Profiling.profileAppStarts = sender.isOn
    }

    @IBAction func defineProfilesSampleRateToggled(_ sender: UISwitch) {
        sampleRateField.isEnabled = sender.isOn
        SentrySDKOverrides.Profiling.sampleRate = getSampleRateOverride(field: sampleRateField)
    }

    @IBAction func defineTracesSampleRateToggled(_ sender: UISwitch) {
        tracesSampleRateField.isEnabled = sender.isOn
        SentrySDKOverrides.Tracing.sampleRate = getSampleRateOverride(field: tracesSampleRateField)
    }

    @IBAction func traceLifecycleToggled(_ sender: UISwitch) {
        SentrySDKOverrides.Profiling.manualLifecycle = !sender.isOn
    }

    @IBAction func sessionSampleRateChanged(_ sender: UITextField) {
        SentrySDKOverrides.Profiling.sessionSampleRate = getSampleRateOverride(field: sender)
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

private extension ProfilingViewController {
    func withProfile(continuous: Bool, block: (URL?) -> Void) {
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
    
    func handleContents(file: URL?) {
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

    func optionsConfiguration() {
        guard let options = SentrySDK.currentHub().getClient()?.options else { return }

        if let sampleRate = options.profilesSampleRate {
            sampleRateField.text = String(format: "%.2f", sampleRate.floatValue)
            sampleRateField.isEnabled = true
            profilesSampleRateSwitch.isOn = true
        } else {
            sampleRateField.isEnabled = false
            sampleRateField.text = "nil"
            profilesSampleRateSwitch.isOn = false
        }

        if let sampleRate = options.tracesSampleRate {
            tracesSampleRateField.text = String(format: "%.2f", sampleRate.floatValue)
            tracesSampleRateField.isEnabled = true
            tracesSampleRateSwitch.isOn = true
        } else {
            tracesSampleRateField.text = "nil"
            tracesSampleRateField.isEnabled = false
            tracesSampleRateSwitch.isOn = false
        }

        if let v2Options = options.profiling {
            traceLifecycleSwitch.isOn = v2Options.lifecycle == .trace
            sessionSampleRateField.text = String(format: "%.2f", v2Options.sessionSampleRate)
            profileAppStartsSwitch.isOn = v2Options.profileAppStarts
        } else {
            traceLifecycleSwitch.isOn = false
            profileAppStartsSwitch.isOn = options.enableAppLaunchProfiling
        }
    }

    func getSampleRateOverride(field: UITextField) -> Float? {
        guard let text = field.text, !text.isEmpty else {
            return nil
        }

        return (text as NSString).floatValue
    }
}
