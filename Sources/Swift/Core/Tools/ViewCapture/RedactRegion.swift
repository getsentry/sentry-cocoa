#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit

@objc public class RedactRegion: NSObject, Encodable {
    enum CodingKeys: CodingKey {
        case size
        case transform
        case type
        case color
        case name
    }

    public let size: CGSize
    public let transform: CGAffineTransform
    public let type: RedactRegionType
    public let color: UIColor?
    public let name: String

    init(size: CGSize, transform: CGAffineTransform, type: RedactRegionType, color: UIColor? = nil, name: String) {
        self.size = size
        self.transform = transform
        self.type = type
        self.color = color
        self.name = name
        super.init()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(transform, forKey: .transform)
        try container.encode(type, forKey: .type)
        try container.encode(UIColorBox(color), forKey: .color)
        try container.encode(name, forKey: .name)
    }

    func canReplace(as other: RedactRegion) -> Bool {
        size == other.size && transform == other.transform && type == other.type
    }
}

private struct UIColorBox: Codable {
    let color: UIColor?

    init(_ color: UIColor?) {
        self.color = color
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let cgColorBox = try container.decode(CGColorBox.self)
        if let cgColor = cgColorBox.cgColor {
            color = UIColor(cgColor: cgColor)
        } else {
            color = nil
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(CGColorBox(color?.cgColor))
    }
}

private struct CGColorBox: Codable {
    let cgColor: CGColor?

    init(_ cgColor: CGColor?) {
        self.cgColor = cgColor
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorData = try container.decode(CGColorData.self)

        guard let colorSpace = CGColorSpace(name: colorData.colorSpaceName as CFString),
              let cgColor = CGColor(colorSpace: colorSpace, components: colorData.components) else {
            self.cgColor = nil
            return
        }

        self.cgColor = cgColor
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        guard let cgColor = cgColor,
              let colorSpaceName = cgColor.colorSpace?.name as String?,
              let components = cgColor.components else {
            try container.encodeNil()
            return
        }

        let colorData = CGColorData(components: components, colorSpaceName: colorSpaceName)
        try container.encode(colorData)
    }
}

private struct CGColorData: Codable {
    let components: [CGFloat]
    let colorSpaceName: String
}

#endif
#endif
