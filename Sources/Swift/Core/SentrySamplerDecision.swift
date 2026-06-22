import Foundation

// swiftlint:disable missing_docs

@objcMembers
public class SentrySamplerDecision: NSObject {
    public let decision: SentrySampleDecision
    public let sampleRand: NSNumber?
    public let sampleRate: NSNumber?

    public init(decision: SentrySampleDecision, forSampleRate sampleRate: NSNumber?, withSampleRand sampleRand: NSNumber?) {
        self.decision = decision
        self.sampleRate = sampleRate
        self.sampleRand = sampleRand
    }
}
