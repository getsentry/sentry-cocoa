import QuartzCore

@objc public class SentryViewHierarchyNode: NSObject, Encodable {
    enum CodingKeys: CodingKey {
        case layer
        case children
    }

    private let layer: CALayerBox?

    public var children: [SentryViewHierarchyNode]

    init(layer: CALayer?, children: [SentryViewHierarchyNode] = []) {
        // Do not keep a reference to the layer, as it would require all encoding to be done on the main thread.
        // Instead we store a box of relevant layer information.
        if let layer = layer {
            self.layer = CALayerBox(layer)
        } else {
            self.layer = nil
        }
        self.children = children
        super.init()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        if let layer = layer {
            try container.encode(layer, forKey: .layer)
        }
    }

    public static func == (lhs: SentryViewHierarchyNode, rhs: SentryViewHierarchyNode) -> Bool {
        if !lhs.children.elementsEqual(rhs.children) {
            return false
        }
        return lhs.layer == rhs.layer
    }
}

public struct CALayerBox: Encodable, Equatable {
    enum CodingKeys: CodingKey {
        case description
        case frame
        case delegateType
        case type
    }

    let layerType: String
    let layerDelegateType: String
    let frame: CGRect

    init(_ layer: CALayer) {
        self.layerType = type(of: layer).description()
        self.layerDelegateType = String(describing: layer.delegate)
        self.frame = layer.frame
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layerType, forKey: .type)
        try container.encode(layerDelegateType, forKey: .delegateType)
        try container.encode(frame, forKey: .frame)
    }

    public static func == (lhs: CALayerBox, rhs: CALayerBox) -> Bool {
        if lhs.layerType != rhs.layerType {
            return false
        }
        if lhs.layerDelegateType != rhs.layerDelegateType {
            return false
        }
        if lhs.frame != rhs.frame {
            return false
        }
        return true
    }
}
