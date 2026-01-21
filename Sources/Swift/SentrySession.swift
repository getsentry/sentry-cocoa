// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

enum SentrySessionStatus: String {
    case ok
    case exited
    case crashed
    case abnormal
}

// swiftlint:disable type_body_length
/// The SDK uses SentrySession to inform Sentry about release and project associated project health.
@objc @_spi(Private) public class SentrySession: NSObject, NSCopying {

    // MARK: - Private properties

    private let lock = NSLock()
    private var _sessionId: UUID
    private var _started: Date
    private var _status: SentrySessionStatus
    private var _errors: UInt
    private var _sequence: UInt
    private var _distinctId: String
    private var _flagInit: NSNumber?
    private var _timestamp: Date?
    private var _duration: NSNumber?
    private var _releaseName: String?
    private var _environment: String?
    private var _abnormalMechanism: String?

    // MARK: - Initializers

    @available(*, unavailable, message: "Use init(releaseName:distinctId:) instead.")
    private override init() {
        fatalError("Not Implemented")
    }

    /// Designated initializer.
    @objc public init(releaseName: String, distinctId: String) {
        _sessionId = UUID()
        _started = SentryDependencyContainer.sharedInstance().dateProvider.date()
        _status = .ok
        _sequence = 1
        _errors = 0
        _distinctId = distinctId
        _flagInit = NSNumber(value: true)
        _releaseName = releaseName
    }

    /// Private initializer for copying.
    private init(
        sessionId: UUID,
        started: Date,
        status: SentrySessionStatus,
        errors: UInt,
        sequence: UInt,
        distinctId: String,
        flagInit: NSNumber?,
        timestamp: Date?,
        duration: NSNumber?,
        releaseName: String?,
        environment: String?,
        abnormalMechanism: String?
    ) {
        _sessionId = sessionId
        _started = started
        _status = status
        _errors = errors
        _sequence = sequence
        _distinctId = distinctId
        _flagInit = flagInit
        _timestamp = timestamp
        _duration = duration
        _releaseName = releaseName
        _environment = environment
        _abnormalMechanism = abnormalMechanism
    }

    /**
     * Initializes @c SentrySession from a JSON object.
     * @param jsonObject The @c jsonObject containing the session.
     * @return The @c SentrySession or @c nil if @c jsonObject contains an error.
     */
    // swiftlint:disable cyclomatic_complexity
    @objc(initWithJSONObject:) public init?(jsonObject: [String: Any]) {
        // Session ID
        guard let sidString = jsonObject["sid"] as? String,
              !sidString.isEmpty,
              let sessionId = UUID(uuidString: sidString) else {
            return nil
        }
        _sessionId = sessionId

        // Started
        guard let startedString = jsonObject["started"] as? String,
              let startedDate = sentry_fromIso8601String(startedString) else {
            return nil
        }
        _started = startedDate

        // Status
        guard let statusString = jsonObject["status"] as? String,
              let status = SentrySessionStatus(rawValue: statusString) else {
            return nil
        }
        _status = status

        // Sequence
        guard let seq = jsonObject["seq"] as? NSNumber else {
            return nil
        }
        _sequence = seq.uintValue

        // Errors
        guard let errors = jsonObject["errors"] as? NSNumber else {
            return nil
        }
        _errors = errors.uintValue

        // Distinct ID
        guard let did = jsonObject["did"] as? String else {
            return nil
        }
        _distinctId = did

        // Optional: init flag
        if let initFlag = jsonObject["init"] as? NSNumber {
            _flagInit = initFlag
        }

        // Optional: attrs (release, environment)
        if let attrs = jsonObject["attrs"] as? [String: Any] {
            if let releaseName = attrs["release"] as? String {
                _releaseName = releaseName
            }
            if let environment = attrs["environment"] as? String {
                _environment = environment
            }
        }

        // Optional: timestamp
        if let timestampString = jsonObject["timestamp"] as? String {
            _timestamp = sentry_fromIso8601String(timestampString)
        }

        // Optional: duration
        if let duration = jsonObject["duration"] as? NSNumber {
            _duration = duration
        }

        // Optional: abnormal_mechanism
        if let abnormalMechanism = jsonObject["abnormal_mechanism"] as? String {
            _abnormalMechanism = abnormalMechanism
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // MARK: - Public methods

    @objc(endSessionExitedWithTimestamp:)
    public func endExited(withTimestamp timestamp: Date) {
        lock.lock()
        defer { lock.unlock() }
        changed()
        _status = .exited
        endSession(withTimestamp: timestamp)
    }

    @objc(endSessionCrashedWithTimestamp:)
    public func endCrashed(withTimestamp timestamp: Date) {
        lock.lock()
        defer { lock.unlock() }
        changed()
        _status = .crashed
        endSession(withTimestamp: timestamp)
    }

    @objc(endSessionAbnormalWithTimestamp:)
    public func endAbnormal(withTimestamp timestamp: Date) {
        lock.lock()
        defer { lock.unlock() }
        changed()
        _status = .abnormal
        endSession(withTimestamp: timestamp)
    }

    @objc public func incrementErrors() {
        lock.lock()
        defer { lock.unlock() }
        changed()
        _errors += 1
    }

    @objc public func setFlagInit() {
        lock.lock()
        defer { lock.unlock() }
        _flagInit = NSNumber(value: true)
    }

    @objc public func serialize() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        var serializedData: [String: Any] = [
            "sid": _sessionId.uuidString,
            "errors": _errors,
            "started": sentry_toIso8601String(_started)
        ]

        if let flagInit = _flagInit {
            serializedData["init"] = NSNumber(value: flagInit.boolValue)
        }

        serializedData["status"] = _status.rawValue

        let timestamp = _timestamp ?? SentryDependencyContainer.sharedInstance().dateProvider.date()
        serializedData["timestamp"] = sentry_toIso8601String(timestamp)

        if let duration = _duration {
            serializedData["duration"] = duration
        } else if _flagInit == nil {
            if let secondsBetween = _timestamp?.timeIntervalSince(_started) {
                serializedData["duration"] = NSNumber(value: secondsBetween)
            } else {
                serializedData["duration"] = NSNumber(value: 0)
            }
        }

        serializedData["seq"] = _sequence

        if _releaseName != nil || _environment != nil {
            var attrs: [String: Any] = [:]
            if let releaseName = _releaseName {
                attrs["release"] = releaseName
            }
            if let environment = _environment {
                attrs["environment"] = environment
            }
            serializedData["attrs"] = attrs
        }

        serializedData["did"] = _distinctId

        if let abnormalMechanism = _abnormalMechanism {
            serializedData["abnormal_mechanism"] = abnormalMechanism
        }

        return serializedData
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        lock.lock()
        defer { lock.unlock() }
        return SentrySession(
            sessionId: _sessionId,
            started: _started,
            status: _status,
            errors: _errors,
            sequence: _sequence,
            distinctId: _distinctId,
            flagInit: _flagInit,
            timestamp: _timestamp,
            duration: _duration,
            releaseName: _releaseName,
            environment: _environment,
            abnormalMechanism: _abnormalMechanism
        )
    }

    // MARK: - Public properties

    @objc public var sessionId: UUID {
        lock.lock()
        defer { lock.unlock() }
        return _sessionId
    }

    @objc public var started: Date {
        lock.lock()
        defer { lock.unlock() }
        return _started
    }

    var status: SentrySessionStatus {
        lock.lock()
        defer { lock.unlock() }
        return _status
    }

    @objc public var errors: UInt {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _errors
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _errors = newValue
        }
    }

    @objc public var sequence: UInt {
        lock.lock()
        defer { lock.unlock() }
        return _sequence
    }

    @objc public var distinctId: String {
        lock.lock()
        defer { lock.unlock() }
        return _distinctId
    }

    @objc public var flagInit: NSNumber? {
        lock.lock()
        defer { lock.unlock() }
        return _flagInit
    }

    @objc public var timestamp: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _timestamp
    }

    @objc public var duration: NSNumber? {
        lock.lock()
        defer { lock.unlock() }
        return _duration
    }

    @objc public var releaseName: String? {
        lock.lock()
        defer { lock.unlock() }
        return _releaseName
    }

    @objc public var environment: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _environment
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _environment = newValue
        }
    }

    @objc public var abnormalMechanism: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _abnormalMechanism
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _abnormalMechanism = newValue
        }
    }

    // MARK: - Private methods

    private func endSession(withTimestamp timestamp: Date) {
        _timestamp = timestamp
        let secondsBetween = timestamp.timeIntervalSince(_started)
        _duration = NSNumber(value: secondsBetween)
    }

    private func changed() {
        _flagInit = nil
        _sequence += 1
    }
}
// swiftlint:enable missing_docs, type_body_length
