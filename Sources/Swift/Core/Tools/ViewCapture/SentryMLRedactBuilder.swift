#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import UIKit
import CoreML
@_implementationOnly import _SentryPrivate
import Vision

@objcMembers
@_spi(Private) public class SentryMLRedactBuilder: NSObject, SentryUIRedactBuilderProtocol {
    private static let modelInputSize: CGFloat = 640.0
    private let mlModel: MLModel
    private let queue: DispatchQueue
    private let classNames: [Int: String]
 
    required public init(options: SentryRedactOptions) {
        // Load the model at initialization time
        guard #available(iOS 17.0, *) else {
            fatalError(
                "[Sentry] Warning: The iOS 17.0 ML model is not available. " +
                "Please update your SDK to a version that supports it."
            )
        }
        
        var loadedClassNames: [Int: String] = [:]
        
        do {
            // Try to load the compiled model from the bundle
            guard let modelURL = Bundle(for: Self.self).url(forResource: "SentryMaskingModel", withExtension: "mlmodelc") else {
                fatalError("[Sentry] Warning: Could not find SentryMaskingModel.mlmodelc in bundle")
            }
            
            let config = MLModelConfiguration()
            self.mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            
            // Parse class names from model metadata
            if let metadata = self.mlModel.modelDescription.metadata[.creatorDefinedKey] as? [String: String],
               let namesString = metadata["names"] {
                // Parse Python dict string like: "{0: 'BackgroundImage', 1: 'Bottom_Navigation', ...}"
                let cleaned = namesString
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")
                    .replacingOccurrences(of: "'", with: "")
                
                let pairs = cleaned.components(separatedBy: ", ")
                for pair in pairs {
                    let parts = pair.components(separatedBy: ": ")
                    if parts.count == 2,
                       let classId = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                       !parts[1].isEmpty {
                        loadedClassNames[classId] = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                }
                print("[Sentry] Loaded \(loadedClassNames.count) class names from model metadata")
            }
        } catch {
            fatalError("[Sentry] Warning: Failed to load ML model: \(error)")
        }
 
        self.classNames = loadedClassNames
        // Run ML inference asynchronously on a background queue to avoid blocking
        queue = DispatchQueue.global(qos: .userInitiated)
        super.init()
    }

    public func addIgnoreClass(_ ignoreClass: AnyClass) {}

    public func addRedactClass(_ redactClass: AnyClass) {}

    public func addIgnoreClasses(_ ignoreClasses: [AnyClass]) {}

    public func addRedactClasses(_ redactClasses: [AnyClass]) {}

    public func setIgnoreContainerClass(_ containerClass: AnyClass) {}

    public func setRedactContainerClass(_ containerClass: AnyClass) {}

    public func redactRegionsFor(view: UIView, image: UIImage, callback: @escaping ([SentryRedactRegion]?, Error?) -> Void) {
        guard #available(iOS 17.0, *) else {
            callback([], nil)
            return
        }

         // Debug: Print view hierarchy (comment out for production)
         if let viewDescription = view.value(forKey: "recursiveDescription") as? String {
             print("[Sentry] View Hierarchy:\n\(viewDescription)")
         }

        queue.async { [weak self] in
            guard let self = self else {
                callback([], nil)
                return
            }
            
            do {
                // Store original size for scaling back
                let originalSize = image.size
                
                // Calculate letterbox/pillarbox scaling to maintain aspect ratio
                let targetSize = Self.modelInputSize
                let widthRatio = targetSize / originalSize.width
                let heightRatio = targetSize / originalSize.height
                let scaleFactor = min(widthRatio, heightRatio)
                
                let scaledWidth = originalSize.width * scaleFactor
                let scaledHeight = originalSize.height * scaleFactor
                
                // Calculate offsets for centering in 640x640
                let xOffset = (targetSize - scaledWidth) / 2.0
                let yOffset = (targetSize - scaledHeight) / 2.0
                
                print("[Sentry] Letterbox info:")
                print("  Original: \(originalSize.width)x\(originalSize.height)")
                print("  Scaled to: \(scaledWidth)x\(scaledHeight) (scale: \(scaleFactor))")
                print("  Centered at: x=\(xOffset), y=\(yOffset) in 640x640")
                
                // Resize image to 640x640 with letterboxing (maintains aspect ratio)
//                let resizedImage = self.resizeImage(
//                    image,
//                    targetSize: targetSize
//                )

                // Convert to CVPixelBuffer
//                guard let pixelBuffer = self.createPixelBuffer(from: resizedImage) else {
//                    print("[Sentry] Warning: Failed to create pixel buffer")
//                    callback([], nil)
//                    return
//                }
                
                // Create input feature dictionary
//                let inputFeatures: [String: Any] = [
//                    "image": pixelBuffer,
//                    "iouThreshold": 0.7,
//                    "confidenceThreshold": 0.25
//                ]
                
                // let input = try MLDictionaryFeatureProvider(dictionary: inputFeatures)

                // Run prediction - this is the expensive operation
                // let output = try self.mlModel.prediction(from: input)

                let model = try VNCoreMLModel(for: self.mlModel)
                model.inputImageFeatureName = "image"

                let request = VNCoreMLRequest(model: model) { request, error in
                    guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                        fatalError()
                    }
                    var regions = [SentryRedactRegion]()
                    let renderer = UIGraphicsImageRenderer(size: image.size)
                    let masked = renderer.image { context in
                        image.draw(at: .zero)

                        context.cgContext.setStrokeColor(UIColor.red.cgColor)
                        context.cgContext.setLineWidth(2)

                        for observation in observations {
                            let rect = Self.denormalizeRect(observation.boundingBox, imageSize: image.size)
                            context.cgContext.stroke(rect)
                            regions.append(SentryRedactRegion(
                                size: rect.size,
                                transform: CGAffineTransformMakeTranslation(rect.origin.x, rect.origin.y),
                                type: .redact,
                                color: .red.withAlphaComponent(0.3),
                                name: observation.description
                            ))
                        }
                    }
                    print(masked)

                    callback(regions, nil)
                }
                request.imageCropAndScaleOption = .scaleFill

                let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
                FileManager.default.createFile(atPath: tempUrl.path, contents: nil, attributes: nil)
                try image.pngData()!.write(to: tempUrl)
                let ciImage = CIImage(contentsOf: tempUrl)!
                // let handler = VNImageRequestHandler(url: tempUrl)
                let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)
                try handler.perform([request])


//                // Parse the output
//                guard let coordinatesFeature = output.featureValue(for: "coordinates"),
//                      let confidenceFeature = output.featureValue(for: "confidence") else {
//                    SentrySDKLog.error("[Sentry] Warning: Could not extract coordinates or confidence from model output")
//                    callback([], nil)
//                    return
//                }
//                
//                // Convert MLMultiArray to regions
//                let regions = self.parseModelOutput(
//                    coordinates: coordinatesFeature.multiArrayValue,
//                    confidence: confidenceFeature.multiArrayValue,
//                    scaleFactor: scaleFactor,
//                    xOffset: xOffset,
//                    yOffset: yOffset,
//                    originalSize: originalSize,
//                    classNames: self.classNames
//                )
//                
//                // Debug: Print region summary
//                print("[Sentry] Generated \(regions.count) redact regions from \(coordinatesFeature.multiArrayValue?.shape[0].intValue ?? 0) detections")
//                for (idx, region) in regions.enumerated() {
//                    print("  Region \(idx): \(region.name) at (\(region.transform.tx), \(region.transform.ty)) size=\(region.size)")
//                }

//                callback(regions, nil)
            } catch {
                SentrySDKLog.error("[Sentry] Warning: ML inference failed: \(error)")
                callback(nil, error)
            }
        }
    }
    
    private func resizeImage(
        _ image: UIImage,
        targetSize: CGFloat,
    ) -> UIImage {
        // let scaledWidth = image.size.width / image.size.height * targetSize
        let size = CGSize(width: targetSize, height: targetSize)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        UIRectFill(CGRect(origin: .zero, size: size))

        image.draw(in: CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: size.height
        ))

        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    private func resizeImageWithLetterbox(
        _ image: UIImage,
        targetSize: CGFloat,
        scaledWidth: CGFloat,
        scaledHeight: CGFloat,
        xOffset: CGFloat,
        yOffset: CGFloat
    ) -> UIImage {
        let size = CGSize(width: targetSize, height: targetSize)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        // Fill with black (letterbox padding)
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Draw image centered with aspect ratio maintained
        image.draw(in: CGRect(
            x: xOffset,
            y: yOffset,
            width: scaledWidth,
            height: scaledHeight
        ))

        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    func createPixelBuffer(from uiImage: UIImage) -> CVPixelBuffer? {
        // Normalize orientation first (renders to .up)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = uiImage.scale
        let normalized = UIGraphicsImageRenderer(size: uiImage.size, format: fmt).image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
        }
        guard let cgImage = normalized.cgImage else { return nil }

        let width  = cgImage.width
        let height = cgImage.height

        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],   // helps with pools/Metal
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo  = CGBitmapInfo.byteOrder32Little
            .union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))

        guard let ctx = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        // Flip for CoreGraphics coordinate system
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }

    private func parseModelOutput(
        coordinates: MLMultiArray?,
        confidence: MLMultiArray?,
        scaleFactor: CGFloat,
        xOffset: CGFloat,
        yOffset: CGFloat,
        originalSize: CGSize,
        classNames: [Int: String]
    ) -> [SentryRedactRegion] {
        guard let coords = coordinates, let confs = confidence else {
            return []
        }
        
        var regions: [SentryRedactRegion] = []
        
        // The model outputs: coordinates [N, 4] where each row is [x_center, y_center, width, height]
        // YOLO models output the CENTER of the bounding box, not the top-left corner
        // Coordinates are normalized (0-1) relative to the 640x640 input
        
        let numBoxes = coords.shape[0].intValue
        let modelSize = Self.modelInputSize
        
        for i in 0..<numBoxes {
            // Extract bounding box coordinates (CENTER point + dimensions)
            // These are normalized 0-1 relative to the 640x640 input
            let xCenterNorm = CGFloat(truncating: coords[[i, 0] as [NSNumber]])
            let yCenterNorm = CGFloat(truncating: coords[[i, 1] as [NSNumber]])
            let widthNorm = CGFloat(truncating: coords[[i, 2] as [NSNumber]])
            let heightNorm = CGFloat(truncating: coords[[i, 3] as [NSNumber]])
            
            // Skip invalid boxes
            guard widthNorm > 0 && heightNorm > 0 else {
                continue
            }
            
            // Convert normalized coordinates to pixels in 640x640 space
            let xCenter640 = xCenterNorm * modelSize
            let yCenter640 = yCenterNorm * modelSize
            let width640 = widthNorm * modelSize
            let height640 = heightNorm * modelSize
            
            // Subtract letterbox offsets to get coordinates in the letterboxed image space
            let xCenterLetterbox = xCenter640 - xOffset
            let yCenterLetterbox = yCenter640 - yOffset
            
            // Scale back to original image size
            let xCenterOriginal = xCenterLetterbox / scaleFactor
            let yCenterOriginal = yCenterLetterbox / scaleFactor
            let widthOriginal = width640 / scaleFactor
            let heightOriginal = height640 / scaleFactor

            var detectedClasses: [(name: String, confidence: Float)] = []
            if confs.shape.count >= 2 {
                let numClasses = confs.shape[1].intValue
                for classId in 0..<numClasses {
                    let conf = confs[[i, classId] as [NSNumber]].floatValue
                    if conf > 0 {
                        detectedClasses += [
                            (name: classNames[classId] ?? "Unknown", confidence: floor(conf * 100))
                        ]
                    }
                }
            }
            if detectedClasses.isEmpty {
                continue;
            }
            let className = detectedClasses.sorted { lhs, rhs in
                lhs.confidence > rhs.confidence
            }.map { (name, confidence) in
                "\(name) (\(confidence)%)"
            }.joined(separator: ", ")

            // Debug: Print conversion for ALL boxes
            print("[Sentry] Box \(i) \(className):")
            print("  Normalized: center=(\(xCenterNorm), \(yCenterNorm)) size=(\(widthNorm), \(heightNorm))")
            print("  640x640: center=(\(xCenter640), \(yCenter640))")
            print("  After removing letterbox: center=(\(xCenterLetterbox), \(yCenterLetterbox))")
            print("  Original space: center=(\(xCenterOriginal), \(yCenterOriginal))")

            // Create transform for this region using clamped coordinates
            let transform = CGAffineTransform(translationX: xCenterOriginal, y: yCenterOriginal)

            // Create redact region with clamped size and descriptive name
            let region = SentryRedactRegion(
                size: CGSize(width: widthOriginal, height: heightOriginal),
                transform: transform,
                type: .redact,
                color: UIColor.red,
                name: className
            )
            
            regions.append(region)
        }
        
        return regions
    }

//    /// Convert normalized bounding box (0-1) to actual pixel coordinates
//    /// - Parameters:
//    ///   - normalizedRect: CGRect with normalized coordinates (0-1) from Vision (bottom-left origin)
//    ///   - imageSize: Size of the image
//    /// - Returns: CGRect in pixel coordinates (top-left origin for UIKit)
//    static func denormalizeRect(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
//        // When using .centerCrop, Vision crops to the center square of the image
//        // The crop size is min(width, height)
//        let cropSize = min(imageSize.width, imageSize.height)
//
//        // Calculate crop offsets (how much was cropped from each side)
//        let xOffset = (imageSize.width - cropSize) / 2.0
//        let yOffset = (imageSize.height - cropSize) / 2.0
//
//        // Scale normalized coordinates to the crop region
//        let x = normalizedRect.origin.x * cropSize + xOffset
//        let width = normalizedRect.width * cropSize
//        let height = normalizedRect.height * cropSize
//
//        // Vision uses bottom-left origin, convert to top-left (UIKit)
//        // Within the crop region, flip the y coordinate
//        let yInCrop = (1 - normalizedRect.origin.y - normalizedRect.height) * cropSize
//        let y = yInCrop + yOffset
//
//        return CGRect(x: x, y: y, width: width, height: height)
//    }

    static func denormalizeRect(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        // ScaleFill: Image is stretched to model input size, no cropping
        // Simply scale normalized coordinates to image dimensions
        let x = normalizedRect.origin.x * imageSize.width
        let width = normalizedRect.width * imageSize.width
        let height = normalizedRect.height * imageSize.height

        // Vision uses bottom-left origin, convert to top-left (UIKit)
        let y = (1 - normalizedRect.origin.y - normalizedRect.height) * imageSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
