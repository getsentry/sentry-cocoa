import CoreGraphics

/// Platform-agnostic + Swift port of Panic's ColorArt algorithms:
/// https://github.com/panicinc/ColorArt/blob/master/ColorArt/SLColorArt.m
struct ColorArt {
    enum ColorArtError: Swift.Error {
        case contextCreationFailed
        case backgroundColorNotFound
    }

    struct Colors {
        let backgroundColor: CGColor?
        let primaryColor: CGColor?
        let secondaryColor: CGColor?
        let detailColor: CGColor?
        let isDarkBackground: Bool
    }

    /// Analyzes an image by first scaling it down to the specified size, and
    /// then analyzing colors to pick context-appropriate background and text
    /// colors.
    ///
    /// - Parameters:
    ///   - image: The image to analze.
    ///   - width: The width to scale the image down to.
    ///   - height: The height to scale the image down to.
    ///   - dominantEdge: The dominant edge to sample background colors from.
    /// - Returns: Background and text colors
    /// - Throws: `ColorArt.Error` if image analysis failed
    static func analyzeImage(_ image: CGImage, width: Int, height: Int, dominantEdge: CGRectEdge) throws -> Colors {
        let span = Tracer.startSpan(name: "analyze-image")
        span.annotate(key: "width", value: String(width))
        span.annotate(key: "height", value: String(height))
        defer { span.end() }

        let components = try findColorComponents(image: image, width: width, height: height, dominantEdge: dominantEdge)
        guard let backgroundColor = findBackgroundColorComponents(components: components) else {
            throw ColorArtError.backgroundColorNotFound
        }
        let darkBackground = backgroundColor.isDarkColor
        let textColorComponents = findTextColorComponents(colors: components.allColors, backgroundColor: backgroundColor)
        let getColor: (RGBADecimalComponents?) -> CGColor? = { components in
            components?.color ?? (darkBackground ? whiteCGColor() : blackCGColor())
        }
        return Colors(
            backgroundColor: backgroundColor.color,
            primaryColor: getColor(textColorComponents.primaryColor),
            secondaryColor: getColor(textColorComponents.secondaryColor),
            detailColor: getColor(textColorComponents.detailColor),
            isDarkBackground: darkBackground
        )
    }
}

private func whiteCGColor() -> CGColor? {
    CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: [1.0, 1.0])
}

private func blackCGColor() -> CGColor? {
    CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: [0.0, 1.0])
}

private struct TextColorComponents {
    var primaryColor: RGBADecimalComponents?
    var secondaryColor: RGBADecimalComponents?
    var detailColor: RGBADecimalComponents?
}

private func findTextColorComponents(colors: CountedSet<RGBADecimalComponents>, backgroundColor: RGBADecimalComponents) -> TextColorComponents {
    var sortedColors = [CountedContainer<RGBADecimalComponents>]()
    sortedColors.reserveCapacity(colors.count)
    let findDarkTextColor = !backgroundColor.isDarkColor
    for (color, count) in colors {
        let saturatedColor = color.componentsWithMinimumSaturation(0.15)
        if saturatedColor.isDarkColor == findDarkTextColor {
            let container = CountedContainer(value: saturatedColor, count: count)
            sortedColors.append(container)
        }
    }
    sortedColors.sort(by: { $0.count > $1.count })

    var components = TextColorComponents()
    for container in sortedColors {
        let color = container.value
        if components.primaryColor == nil {
            if color.isContrasting(components: backgroundColor) {
                components.primaryColor = color
            }
        } else if let primaryColor = components.primaryColor, components.secondaryColor == nil {
            if !primaryColor.isDistinct(components: color) || !color.isContrasting(components: backgroundColor) {
                continue
            }
            components.secondaryColor = color
        } else if let primaryColor = components.primaryColor, let secondaryColor = components.secondaryColor, components.detailColor == nil {
            if !secondaryColor.isDistinct(components: color) || !primaryColor.isDistinct(components: color) || !color.isContrasting(components: backgroundColor) {
                continue
            }
            components.detailColor = color
            break
        }
    }
    return components
}

private func findBackgroundColorComponents(components: ColorComponents) -> RGBADecimalComponents? {
    var sortedColors = [CountedContainer<RGBADecimalComponents>]()
    for (edgeColor, count) in components.edgeColors {
        let randomColorsThreshold = Int(CGFloat(components.height) * 0.01)
        if count < randomColorsThreshold {
            // Prevent using random colors.
            continue
        }
        let container = CountedContainer(value: edgeColor, count: count)
        sortedColors.append(container)
    }
    sortedColors.sort(by: { $0.count > $1.count })
    if !sortedColors.isEmpty {
        var proposedColor = sortedColors[0]
        // Try to find something other than black or white.
        if proposedColor.value.isBlackOrWhite {
            for nextColor in sortedColors.dropFirst() {
                // Make sure the second color choice is 30% as common as the first choice.
                if (CGFloat(nextColor.count) / CGFloat(proposedColor.count)) > 0.3 {
                    if !nextColor.value.isBlackOrWhite {
                        proposedColor = nextColor
                    }
                } else {
                    // Reached color threshold less than 30% of the original proposed
                    // edge color so bail.
                    break
                }
            }
        }
        return proposedColor.value
    } else {
        return nil
    }
}

private struct ColorComponents {
    let width: Int
    let height: Int
    let allColors: CountedSet<RGBADecimalComponents>
    let edgeColors: CountedSet<RGBADecimalComponents>
}

private func findColorComponents(image: CGImage, width: Int, height: Int, dominantEdge: CGRectEdge) throws -> ColorComponents {
    // Redraw the image into an RBGA (non-premultiplied) context.
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    ) else {
        throw ColorArt.ColorArtError.contextCreationFailed
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    switch dominantEdge {
    case .minXEdge:
        return findMinXEdgeColorComponents(context: context)
    case .maxXEdge:
        return findMaxXEdgeColorComponents(context: context)
    case .minYEdge:
        return findMinYEdgeColorComponents(context: context)
    case .maxYEdge:
        return findMaxYEdgeColorComponents(context: context)
    }
}

private func findMinXEdgeColorComponents(context: CGContext) -> ColorComponents {
    let (width, height) = (context.width, context.height)
    var allColors = CountedSet<RGBADecimalComponents>(minimumCapacity: width * height)
    var edgeColors = CountedSet<RGBADecimalComponents>(minimumCapacity: height)

    let data = unsafeBitCast(context.data, to: UnsafeMutablePointer<RGBAPixel>.self)
    for y in 0 ..< height {
        var firstMeaningfulComponents: RGBADecimalComponents?
        for x in 0 ..< width {
            let components = RGBADecimalComponents(pixel: data[x + y * width])
            if firstMeaningfulComponents == nil, components.isMeaningful {
                firstMeaningfulComponents = components
            }
            if !components.isTransparent {
                allColors.add(components)
            }
        }
        if let firstMeaningfulComponents = firstMeaningfulComponents {
            edgeColors.add(firstMeaningfulComponents)
        }
    }

    return ColorComponents(width: width,
                           height: height,
                           allColors: allColors,
                           edgeColors: edgeColors)
}

private func findMaxXEdgeColorComponents(context: CGContext) -> ColorComponents {
    let (width, height) = (context.width, context.height)
    var allColors = CountedSet<RGBADecimalComponents>(minimumCapacity: width * height)
    var edgeColors = CountedSet<RGBADecimalComponents>(minimumCapacity: height)

    let data = unsafeBitCast(context.data, to: UnsafeMutablePointer<RGBAPixel>.self)
    for y in 0 ..< height {
        var lastMeaningfulComponents: RGBADecimalComponents?
        for x in 0 ..< width {
            let components = RGBADecimalComponents(pixel: data[x + y * width])
            if components.isMeaningful {
                lastMeaningfulComponents = components
            }
            if !components.isTransparent {
                allColors.add(components)
            }
        }
        if let lastMeaningfulComponents = lastMeaningfulComponents {
            edgeColors.add(lastMeaningfulComponents)
        }
    }

    return ColorComponents(width: width,
                           height: height,
                           allColors: allColors,
                           edgeColors: edgeColors)
}

private func findMinYEdgeColorComponents(context: CGContext) -> ColorComponents {
    let (width, height) = (context.width, context.height)
    var allColors = CountedSet<RGBADecimalComponents>(minimumCapacity: width * height)
    var edgeColors = CountedSet<RGBADecimalComponents>(minimumCapacity: width)

    let data = unsafeBitCast(context.data, to: UnsafeMutablePointer<RGBAPixel>.self)
    var xSlots = [Bool](repeating: false, count: width)
    for y in 0 ..< height {
        for x in 0 ..< width {
            let components = RGBADecimalComponents(pixel: data[x + y * width])
            if !xSlots[x], components.isMeaningful {
                edgeColors.add(components)
                xSlots[x] = true
            }
            if !components.isTransparent {
                allColors.add(components)
            }
        }
    }

    return ColorComponents(width: width,
                           height: height,
                           allColors: allColors,
                           edgeColors: edgeColors)
}

private func findMaxYEdgeColorComponents(context: CGContext) -> ColorComponents {
    let (width, height) = (context.width, context.height)
    var allColors = CountedSet<RGBADecimalComponents>(minimumCapacity: width * height)

    let data = unsafeBitCast(context.data, to: UnsafeMutablePointer<RGBAPixel>.self)
    var xSlots = [RGBADecimalComponents?](repeating: nil, count: width)
    for y in 0 ..< height {
        for x in 0 ..< width {
            let components = RGBADecimalComponents(pixel: data[x + y * width])
            if components.isMeaningful {
                xSlots[x] = components
            }
            if !components.isTransparent {
                allColors.add(components)
            }
        }
    }

    var edgeColors = CountedSet<RGBADecimalComponents>(minimumCapacity: width)
    for components in xSlots {
        if let components = components {
            edgeColors.add(components)
        }
    }

    return ColorComponents(width: width,
                           height: height,
                           allColors: allColors,
                           edgeColors: edgeColors)
}

private struct RGBAPixel {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
}

private struct RGBADecimalComponents: Hashable {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(pixel: RGBAPixel) {
        r = CGFloat(pixel.r) / 255.0
        g = CGFloat(pixel.g) / 255.0
        b = CGFloat(pixel.b) / 255.0
        a = CGFloat(pixel.a) / 255.0
    }

    init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(r)
        hasher.combine(g)
        hasher.combine(b)
        hasher.combine(a)
    }

    // Relative luminance formula: https://en.wikipedia.org/wiki/Relative_luminance
    var luminance: CGFloat {
        0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    var isDarkColor: Bool {
        luminance < 0.5
    }

    var isGray: Bool {
        abs(r - g) < 0.03 && abs(r - b) < 0.03
    }

    var isMeaningful: Bool {
        a > 0.5
    }

    var isTransparent: Bool {
        abs(a) < CGFloat.ulpOfOne
    }

    var isBlackOrWhite: Bool {
        let whiteThreshold: CGFloat = 0.91
        let blackThreshold: CGFloat = 0.09

        return (r > whiteThreshold && g > whiteThreshold && b > whiteThreshold)
            || (r < blackThreshold && g < blackThreshold && b < blackThreshold)
    }

    // From https://github.com/ovenbits/Alexandria/blob/master/Sources/UIColor%2BExtensions.swift
    var hsl: (h: CGFloat, s: CGFloat, l: CGFloat) {
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)

        var h, s: CGFloat
        let l = (max + min) / 2

        if max == min {
            h = 0
            s = 0
        } else {
            let d = max - min
            s = (l > 0.5) ? d / (2 - max - min) : d / (max + min)

            switch max {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            case b: h = (r - g) / d + 4
            default: h = 0
            }

            h /= 6
        }
        return (h, s, l)
    }

    var color: CGColor? {
        CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a])
    }

    func isDistinct(components: RGBADecimalComponents) -> Bool {
        let (r1, g1, b1, a1) = (r, g, b, a)
        let (r2, g2, b2, a2) = (components.r, components.g, components.b, components.a)

        let threshold: CGFloat = 0.25
        let isSufficientlyDifferent = abs(r1 - r2) > threshold
            || abs(g1 - g2) > threshold
            || abs(b1 - b2) > threshold
            || abs(a1 - a2) > threshold
        let bothAreGray = isGray && components.isGray
        return isSufficientlyDifferent && !bothAreGray
    }

    func isContrasting(components: RGBADecimalComponents) -> Bool {
        let (lum1, lum2) = (luminance, components.luminance)
        let contrast: CGFloat
        if lum1 > lum2 {
            contrast = (lum1 + 0.05) / (lum2 + 0.05)
        } else {
            contrast = (lum2 + 0.05) / (lum1 + 0.05)
        }
        return contrast > 1.6
    }

    func componentsWithMinimumSaturation(_ saturation: CGFloat) -> RGBADecimalComponents {
        let (h, s, l) = hsl
        let (r2, g2, b2) = hslToRgb(h: h, s: max(saturation, s), l: l)
        return RGBADecimalComponents(r: r2, g: g2, b: b2, a: a)
    }
}

private func == (lhs: RGBADecimalComponents, rhs: RGBADecimalComponents) -> Bool {
    lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b && lhs.a == rhs.a
}

// From https://github.com/ovenbits/Alexandria/blob/master/Sources/UIColor%2BExtensions.swift
private func hslToRgb(h: CGFloat, s: CGFloat, l: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
    let r, g, b: CGFloat

    if s == 0 {
        r = l
        g = l
        b = l
    } else {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2

        switch h * 6 {
        case 0 ..< 1: (r, g, b) = (c + m, x + m, 0 + m)
        case 1 ..< 2: (r, g, b) = (x + m, c + m, 0 + m)
        case 2 ..< 3: (r, g, b) = (0 + m, c + m, x + m)
        case 3 ..< 4: (r, g, b) = (0 + m, x + m, c + m)
        case 4 ..< 5: (r, g, b) = (x + m, 0 + m, c + m)
        case 5 ..< 6: (r, g, b) = (c + m, 0 + m, x + m)
        default: (r, g, b) = (0 + m, 0 + m, 0 + m)
        }
    }

    return (r, g, b)
}

private struct CountedSet<Value>: Sequence where Value: Hashable {
    typealias Iterator = Dictionary<Value, Int>.Iterator

    private var dictionary: [Value: Int]

    init() {
        dictionary = [Value: Int]()
    }

    init(minimumCapacity: Int) {
        dictionary = [Value: Int](minimumCapacity: minimumCapacity)
    }

    mutating func add(_ value: Value) {
        dictionary[value] = (dictionary[value] ?? 0) + 1
    }

    mutating func remove(_ value: Value) {
        if let existingValue = dictionary[value] {
            if existingValue > 1 {
                dictionary[value] = existingValue - 1
            } else {
                dictionary.removeValue(forKey: value)
            }
        }
    }

    var isEmpty: Bool {
        dictionary.isEmpty
    }

    var count: Int {
        dictionary.count
    }

    func count(for value: Value) -> Int {
        dictionary[value] ?? 0
    }

    __consuming func makeIterator() -> CountedSet<Value>.Iterator {
        dictionary.makeIterator()
    }
}

private struct CountedContainer<Value> {
    let value: Value
    let count: Int
}
