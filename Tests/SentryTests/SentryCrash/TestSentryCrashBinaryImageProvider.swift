import Foundation

@objc
public class TestSentryCrashBinaryImageProvider: NSObject, SentryCrashBinaryImageProvider {
    
    var binaryImage: [SentryCrashBinaryImage] = []
    public func getBinaryImage(_ index: Int) -> SentryCrashBinaryImage {
        getBinaryImage(index, isCrash: true)
    }

    public func getBinaryImage(_ index: Int, isCrash: Bool) -> SentryCrashBinaryImage {
        binaryImage[Int(index)]
    }
    
    var imageCount = Int(0)
    public func getImageCount() -> Int {
        imageCount
    }
}
