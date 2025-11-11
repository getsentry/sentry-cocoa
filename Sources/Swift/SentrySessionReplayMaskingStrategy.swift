@objc(kSentrySessionReplayMaskingStrategy)
public enum SentrySessionReplayMaskingStrategy: Int {
    @objc(kSessionReplayMaskingStrategyViewHierarchy)
    case viewHierarchy = 0

    @objc(kSessionReplayMaskingStrategyAccessibilty)
    case accessibility

    @objc(kSessionReplayMaskingStrategyMachineLearning)
    case machineLearning

    @objc(kSessionReplayMaskingStrategyPDF)
    case pdf

    @objc(kSessionReplayMaskingStrategyWireframe)
    case wireframe

    @objc(kSessionReplayMaskingStrategyDefensive)
    case defensive
}
