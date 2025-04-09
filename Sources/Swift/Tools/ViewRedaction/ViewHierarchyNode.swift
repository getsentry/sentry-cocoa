import QuartzCore

@objc public class ViewHierarchyNode: NSObject, Encodable {
    enum CodingKeys: CodingKey {
        case layer
        case children
    }

    public var layer: CALayer?
    public var children: [ViewHierarchyNode]

    init(layer: CALayer?, children: [ViewHierarchyNode] = []) {
        self.layer = layer
        self.children = children
        super.init()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(children, forKey: .children)
        if let layer = layer {
            try container.encode(CALayerBox(layer), forKey: .layer)
        }
    }

    public static func == (lhs: ViewHierarchyNode, rhs: ViewHierarchyNode) -> Bool {
        if !lhs.children.elementsEqual(rhs.children) {
            return false
        }
        if let lhsLayer = lhs.layer, let rhsLayer = rhs.layer {
            return CALayerBox(lhsLayer) == CALayerBox(rhsLayer)
        }
        return lhs.layer == nil && rhs.layer == nil
    }
}

struct CALayerBox: Encodable, Equatable {
    enum CodingKeys: CodingKey {
        case description
        case frame
        case delegateType
        case type
        case customTag
    }

    let layer: CALayer

    init(_ layer: CALayer) {
        self.layer = layer
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type(of: layer).description(), forKey: .type)
        try container.encode(String(describing: layer.delegate), forKey: .delegateType)
        try container.encode(layer.frame, forKey: .frame)
        try container.encode(layer.customTag, forKey: .customTag)
    }

    static func == (lhs: CALayerBox, rhs: CALayerBox) -> Bool {
        if type(of: lhs.layer).description() != type(of: rhs.layer).description() {
            return false
        }
        if String(describing: type(of: lhs.layer.delegate)) != String(describing: type(of: rhs.layer.delegate)) {
            return false
        }
        if lhs.layer.frame != rhs.layer.frame {
            return false
        }
        return true
    }
}

public extension CALayer {
    static let customTagAssociationKey = UnsafeRawPointer(bitPattern: "customTagAssociationKey".hashValue)!

    var customTag: String? {
        get {
            objc_getAssociatedObject(self, CALayer.customTagAssociationKey) as? String
        }
        set {
            objc_setAssociatedObject(self, CALayer.customTagAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
