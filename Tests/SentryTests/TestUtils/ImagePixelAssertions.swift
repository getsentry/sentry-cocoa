#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
import XCTest

struct ImagePixel {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

func imagePixel(at point: CGPoint, in image: UIImage) -> ImagePixel? {
    guard let cgImage = image.cgImage,
          let pixelData = cgImage.dataProvider?.data,
          let bytes = CFDataGetBytePtr(pixelData) else {
        return nil
    }

    let x = Int(point.x * image.scale)
    let y = Int(point.y * image.scale)
    guard x >= 0, x < cgImage.width, y >= 0, y < cgImage.height else {
        return nil
    }

    let offset = y * cgImage.bytesPerRow + x * 4
    return ImagePixel(
        red: CGFloat(bytes[offset]) / 255,
        green: CGFloat(bytes[offset + 1]) / 255,
        blue: CGFloat(bytes[offset + 2]) / 255,
        alpha: CGFloat(bytes[offset + 3]) / 255
    )
}

func assertImagePixelColor(
    _ expected: UIColor,
    at point: CGPoint,
    in image: UIImage,
    accuracy: CGFloat = 0.01,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let actual = imagePixel(at: point, in: image) else {
        return XCTFail("Could not read image pixel at \(point)", file: file, line: line)
    }

    var expectedRed: CGFloat = 0
    var expectedGreen: CGFloat = 0
    var expectedBlue: CGFloat = 0
    var expectedAlpha: CGFloat = 0
    guard expected.getRed(&expectedRed, green: &expectedGreen, blue: &expectedBlue, alpha: &expectedAlpha) else {
        return XCTFail("Could not convert expected color to RGB", file: file, line: line)
    }

    XCTAssertEqual(actual.red, expectedRed, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.green, expectedGreen, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.blue, expectedBlue, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.alpha, expectedAlpha, accuracy: accuracy, file: file, line: line)
}

func assertImagePixelsEqual(
    _ lhs: ImagePixel,
    _ rhs: ImagePixel,
    accuracy: CGFloat = 0.01,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(lhs.red, rhs.red, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.green, rhs.green, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.blue, rhs.blue, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.alpha, rhs.alpha, accuracy: accuracy, file: file, line: line)
}
#endif
