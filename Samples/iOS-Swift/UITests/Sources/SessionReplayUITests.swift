import SentrySampleShared
import UIKit
import XCTest

final class SessionReplayUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testCameraUI_shouldNotCrashOnIOS26() throws {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            throw XCTSkip("Camera UI is not available on this device.")
        }
        // -- Arrange --
        launchApp()

        // During the beta phase of iOS 26.0 we noticed crashes when traversing the view hierarchy
        // of the camera UI. This test is used to verify that no regression occurs.
        // See https://github.com/getsentry/sentry-cocoa/issues/5647
        app.buttons["Extra"].tap()

        // -- Act --
        app.buttons["show-camera-ui"].tap()
        
        // We need to verify the camera UI is shown by checking for the existence of a UI element.
        // This can be any element that is part of the camera UI and can be found reliably.
        // The "PhotoCapture" button is a good candidate as it is always present when the
        // camera UI is shown.
        let cameraUIElement = app.buttons["PhotoCapture"]
        XCTAssertTrue(cameraUIElement.waitForExistence(timeout: 5))

        // After the Camera UI is shown, we keep it open for 10 seconds to trigger at least one full
        // video segment captured (segments are 5 seconds long).
        delay(seconds: 10)

        // -- Assert --
        // We know the test succeeded if we reach this point without the app crashing.
        XCTAssertTrue(cameraUIElement.waitForExistence(timeout: 5))
    }

    /// Exercises real app UI through Session Replay capture, renderer V2 redaction, and local PNG storage.
    /// The test launches with 100% sampling, opens a mixed UIKit and SwiftUI fixture, maps each
    /// accessibility element into the captured frame, and verifies default and explicit mask/unmask pixels.
    func testReplayFrame_whenMaskingFixtureIsVisible_shouldMaskSensitiveRegions() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("Session Replay requires iOS 16 or later.")
        }
#if SDK_V10
        throw XCTSkip("Replay masking fixture test is excluded under SDK_V10 (KSCrash startup on iOS 26 delays view presentation beyond the 5 s element-existence timeout).")
#endif // SDK_V10

        // -- Arrange --
        launchApp(env: [SentrySDKOverrides.Replay.sessionSampleRate.rawValue: "1"])

        app.buttons["Extra"].tap()
        app.buttons["io.sentry.ui-test.button.get-application-support-directory"].tap()
        let dataMarshalingField = app.textFields["io.sentry.ui-test.text-field.data-marshaling.extras"]
        let applicationSupportPath = try XCTUnwrap(dataMarshalingField.value as? String)
        let cachesURL = URL(fileURLWithPath: applicationSupportPath)
            .deletingLastPathComponent()
            .appendingPathComponent("Caches", isDirectory: true)

        // -- Act --
        app.buttons["Show UI Test"].tap()

        let fixture = ReplayFixtureElements(app: app)
        fixture.all.forEach {
            XCTAssertTrue($0.waitForExistence(timeout: 5), "Replay fixture element \($0) should exist.")
        }

        let replayImage = try waitForReplayFrame(in: cachesURL, capturedAfter: Date().addingTimeInterval(0.5))
        let attachment = XCTAttachment(image: replayImage)
        attachment.name = "Masked Session Replay frame"
        attachment.lifetime = .keepAlways
        add(attachment)

        // -- Assert --
        try assertRegionIsUniform(in: replayImage, element: fixture.maskedLabel)
        try assertRegionIsUniform(in: replayImage, element: fixture.maskedTextField)
        try assertRegionIsUniform(in: replayImage, element: fixture.maskedUIKitImage)
        try assertRegionIsUniform(in: replayImage, element: fixture.animatedLabel)
        try assertRegionIsUniform(in: replayImage, element: fixture.maskedSwiftUIText)
        try assertRegionIsUniform(in: replayImage, element: fixture.maskedSwiftUIImage)
        try assertRegionIsUniform(in: replayImage, element: fixture.explicitlyMaskedView)
        try assertRegionIsUniform(in: replayImage, element: fixture.explicitlyMaskedSwiftUIView)

        try assertSplitRegion(
            in: replayImage,
            element: fixture.explicitlyUnmaskedView,
            leftColor: .red,
            rightColor: .blue
        )
        try assertSplitRegion(
            in: replayImage,
            element: fixture.explicitlyUnmaskedSwiftUIView,
            leftColor: .black,
            rightColor: .white
        )
    }

    func testReplayControls_whenSampleRatesAreZero_shouldBeUsable() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("Session Replay requires iOS 16 or later.")
        }

        launchApp(env: [
            SentrySDKOverrides.Replay.sessionSampleRate.rawValue: "0",
            SentrySDKOverrides.Replay.onErrorSampleRate.rawValue: "0"
        ])

        app.buttons["Extra"].tap()
        app.buttons["Show UI Test"].tap()

        let controls = [
            app.buttons["replay-control-buffer"],
            app.buttons["replay-control-pause"],
            app.buttons["replay-control-resume"],
            app.buttons["replay-control-flush"],
            app.buttons["replay-control-stop"],
            app.buttons["replay-control-start"]
        ]

        for control in controls {
            XCTAssertTrue(control.waitForExistence(timeout: 5))
            control.tap()
        }

        XCTAssertTrue(app.buttons["replay-control-start"].exists)
    }

    private func waitForReplayFrame(in cachesURL: URL, capturedAfter date: Date) throws -> UIImage {
        let timeout = Date().addingTimeInterval(10)
        while Date() < timeout {
            if let frameURL = latestReplayFrame(in: cachesURL, capturedAfter: date),
               let data = try? Data(contentsOf: frameURL),
               let image = UIImage(data: data) {
                return image
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        throw ReplayFrameError.notFound(cachesURL)
    }

    private func latestReplayFrame(in cachesURL: URL, capturedAfter date: Date) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: cachesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return enumerator.compactMap { item -> (url: URL, timestamp: Date)? in
            guard let url = item as? URL,
                  url.pathExtension == "png",
                  url.pathComponents.contains("replay"),
                  let timestampValue = Double(url.deletingPathExtension().lastPathComponent) else {
                return nil
            }
            let timestamp = Date(timeIntervalSinceReferenceDate: timestampValue)
            guard timestamp >= date else { return nil }
            return (url, timestamp)
        }.max(by: { $0.timestamp < $1.timestamp })?.url
    }

    private func assertRegionIsUniform(
        in image: UIImage,
        element: XCUIElement,
        accuracy: CGFloat = 0.08,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let horizontalPositions: [CGFloat] = [0.2, 0.35, 0.65, 0.8]
        let verticalPositions: [CGFloat] = [0.25, 0.5, 0.75]
        guard let referenceHorizontalPosition = horizontalPositions.first,
              let referenceVerticalPosition = verticalPositions.first else {
            return XCTFail("Replay region sample grid must not be empty.", file: file, line: line)
        }

        let reference = try pixel(
            in: image,
            element: element,
            horizontalPosition: referenceHorizontalPosition,
            verticalPosition: referenceVerticalPosition
        )
        for verticalPosition in verticalPositions {
            for horizontalPosition in horizontalPositions {
                let sample = try pixel(
                    in: image,
                    element: element,
                    horizontalPosition: horizontalPosition,
                    verticalPosition: verticalPosition
                )
                let message = "Replay region sample at (\(horizontalPosition), \(verticalPosition)) should match the reference color."
                XCTAssertEqual(sample.red, reference.red, accuracy: accuracy, message, file: file, line: line)
                XCTAssertEqual(sample.green, reference.green, accuracy: accuracy, message, file: file, line: line)
                XCTAssertEqual(sample.blue, reference.blue, accuracy: accuracy, message, file: file, line: line)
                XCTAssertEqual(sample.alpha, reference.alpha, accuracy: accuracy, message, file: file, line: line)
            }
        }
    }

    private func assertSplitRegion(
        in image: UIImage,
        element: XCUIElement,
        leftColor: UIColor,
        rightColor: UIColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let left = try pixel(in: image, element: element, horizontalPosition: 0.25)
        let right = try pixel(in: image, element: element, horizontalPosition: 0.75)
        XCTAssertGreaterThan(colorDistance(left, right), 1.5, file: file, line: line)
        assertPixelColor(leftColor, in: image, element: element, horizontalPosition: 0.25, file: file, line: line)
        assertPixelColor(rightColor, in: image, element: element, horizontalPosition: 0.75, file: file, line: line)
    }

    private func assertPixelColor(
        _ expected: UIColor,
        in image: UIImage,
        element: XCUIElement,
        horizontalPosition: CGFloat,
        accuracy: CGFloat = 0.08,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual = try? pixel(in: image, element: element, horizontalPosition: horizontalPosition) else {
            return XCTFail("Could not read replay image pixel for \(element)", file: file, line: line)
        }

        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0
        guard expected.getRed(
            &expectedRed,
            green: &expectedGreen,
            blue: &expectedBlue,
            alpha: &expectedAlpha
        ) else {
            return XCTFail("Could not convert expected color to RGB", file: file, line: line)
        }

        XCTAssertEqual(actual.red, expectedRed, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.green, expectedGreen, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.blue, expectedBlue, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.alpha, expectedAlpha, accuracy: accuracy, file: file, line: line)
    }

    private func pixel(
        in image: UIImage,
        element: XCUIElement,
        horizontalPosition: CGFloat,
        verticalPosition: CGFloat = 0.5
    ) throws -> ReplayPixel {
        let applicationFrame = app.frame
        let elementFrame = element.frame
        let point = CGPoint(
            x: elementFrame.minX + elementFrame.width * horizontalPosition,
            y: elementFrame.minY + elementFrame.height * verticalPosition
        )
        let imagePoint = CGPoint(
            x: (point.x - applicationFrame.minX) * image.size.width / applicationFrame.width,
            y: (point.y - applicationFrame.minY) * image.size.height / applicationFrame.height
        )

        guard let cgImage = image.cgImage,
              let pixelData = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(pixelData) else {
            throw ReplayFrameError.unreadablePixel(imagePoint)
        }

        let x = Int(imagePoint.x * image.scale)
        let y = Int(imagePoint.y * image.scale)
        guard x >= 0, x < cgImage.width, y >= 0, y < cgImage.height else {
            throw ReplayFrameError.unreadablePixel(imagePoint)
        }

        let offset = y * cgImage.bytesPerRow + x * 4
        return ReplayPixel(
            red: CGFloat(bytes[offset]) / 255,
            green: CGFloat(bytes[offset + 1]) / 255,
            blue: CGFloat(bytes[offset + 2]) / 255,
            alpha: CGFloat(bytes[offset + 3]) / 255
        )
    }

    private func colorDistance(_ lhs: ReplayPixel, _ rhs: ReplayPixel) -> CGFloat {
        abs(lhs.red - rhs.red) + abs(lhs.green - rhs.green) + abs(lhs.blue - rhs.blue)
    }
}

private struct ReplayFixtureElements {
    let maskedLabel: XCUIElement
    let maskedTextField: XCUIElement
    let maskedUIKitImage: XCUIElement
    let animatedLabel: XCUIElement
    let maskedSwiftUIText: XCUIElement
    let maskedSwiftUIImage: XCUIElement
    let explicitlyMaskedView: XCUIElement
    let explicitlyUnmaskedView: XCUIElement
    let explicitlyMaskedSwiftUIView: XCUIElement
    let explicitlyUnmaskedSwiftUIView: XCUIElement

    init(app: XCUIApplication) {
        maskedLabel = app.staticTexts["replay-fixture-uikit-label"]
        maskedTextField = app.textFields["replay-fixture-uikit-text-field"]
        maskedUIKitImage = app.images["replay-fixture-uikit-image"]
        animatedLabel = app.staticTexts["replay-fixture-animated-label"]
        maskedSwiftUIText = app.staticTexts["replay-fixture-swiftui-text"]
        maskedSwiftUIImage = app.images["replay-fixture-swiftui-image"]
        explicitlyMaskedView = app.otherElements["replay-fixture-explicit-mask"]
        explicitlyUnmaskedView = app.otherElements["replay-fixture-explicit-unmask"]
        explicitlyMaskedSwiftUIView = app.otherElements["replay-fixture-swiftui-explicit-mask"]
        explicitlyUnmaskedSwiftUIView = app.images["replay-fixture-swiftui-explicit-unmask"]
    }

    var all: [XCUIElement] {
        [
            maskedLabel,
            maskedTextField,
            maskedUIKitImage,
            animatedLabel,
            maskedSwiftUIText,
            maskedSwiftUIImage,
            explicitlyMaskedView,
            explicitlyUnmaskedView,
            explicitlyMaskedSwiftUIView,
            explicitlyUnmaskedSwiftUIView
        ]
    }
}

private struct ReplayPixel {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

private enum ReplayFrameError: Error {
    case notFound(URL)
    case unreadablePixel(CGPoint)
}
