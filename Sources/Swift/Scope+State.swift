internal import _SentryPrivate
import Foundation

/// Keeps this file linked in static builds. Referenced from `SentrySDKInternal`.
@_spi(Private) @objc public final class PlaceholderScopeStateClass: NSObject {}

extension Scope {
    func storeUser(_ user: User?) {
        synchronized(self) {
            userObject = user
            userWasSet = true
            userPersistenceCallback?(user?.copy() as? User)
            notifyObservers { $0.setUser(user) }
        }
    }

    /// Installs the callback that records explicit user changes.
    ///
    /// When a user was already set, the callback runs immediately with a copy of that user.
    /// Passing `nil` detaches persistence. Copies of a scope do not inherit the callback.
    @_spi(Private)
    @objc(configureUserPersistence:)
    public func configureUserPersistence(_ callback: ((User?) -> Void)?) {
        synchronized(self) {
            userPersistenceCallback = callback
            if let callback, userWasSet {
                callback(userObject?.copy() as? User)
            }
        }
    }

    /// Restores a persisted user only while persistence is active and no explicit user decision has been made.
    @_spi(Private)
    @objc(restorePersistedUser:)
    public func restorePersistedUser(_ user: User) {
        synchronized(self) {
            guard userPersistenceCallback != nil, !userWasSet else { return }
            setUser(user)
        }
    }

    func storeTag(value: String?, key: String) {
        synchronized(tagDictionary) {
            if let value {
                tagDictionary[key] = value
            } else {
                tagDictionary.removeObject(forKey: key)
            }
            let tagsCopy = stringDictionary(tagDictionary)
            notifyObservers { $0.setTags(tagsCopy) }
        }
    }

    func deleteTag(key: String) {
        synchronized(tagDictionary) {
            tagDictionary.removeObject(forKey: key)
            let tagsCopy = stringDictionary(tagDictionary)
            notifyObservers { $0.setTags(tagsCopy) }
        }
    }

    func storeTags(_ tags: [String: String]?) {
        guard let tags else { return }
        let tagsCopy = tags as NSDictionary
        synchronized(tagDictionary) {
            tagDictionary.addEntries(from: tagsCopy as? [AnyHashable: Any] ?? [:])
            let updated = stringDictionary(tagDictionary)
            notifyObservers { $0.setTags(updated) }
        }
    }

    func storeExtras(_ extras: [String: Any]?) {
        guard let extras else { return }
        synchronized(extraDictionary) {
            extraDictionary.addEntries(from: extras)
            let extrasCopy = anyDictionary(extraDictionary)
            notifyObservers { $0.setExtras(extrasCopy) }
        }
    }

    func storeExtra(value: Any?, key: String) {
        synchronized(extraDictionary) {
            extraDictionary.setValue(value, forKey: key)
            let extrasCopy = anyDictionary(extraDictionary)
            notifyObservers { $0.setExtras(extrasCopy) }
        }
    }

    func deleteExtra(key: String) {
        synchronized(extraDictionary) {
            extraDictionary.removeObject(forKey: key)
            let extrasCopy = anyDictionary(extraDictionary)
            notifyObservers { $0.setExtras(extrasCopy) }
        }
    }

    func storeDist(_ dist: String?) {
        distString = dist
        notifyObservers { $0.setDist(dist) }
    }

    func storeEnvironment(_ environment: String?) {
        environmentString = environment
        notifyObservers { $0.setEnvironment(environment) }
    }

    func storeFingerprint(_ fingerprint: [String]?) {
        synchronized(fingerprintArray) {
            fingerprintArray.removeAllObjects()
            if let fingerprint {
                fingerprintArray.addObjects(from: fingerprint)
            }
            let fingerprintCopy = stringArray(fingerprintArray)
            notifyObservers { $0.setFingerprint(fingerprintCopy) }
        }
    }

    func storeLevel(_ level: SentryLevel) {
        levelEnum = level
        notifyObservers { $0.setLevel(level) }
    }

    func storeBreadcrumb(_ crumb: Breadcrumb) {
        guard maxBreadcrumbs >= 1 else { return }
        SentrySDKLog.debug("Add breadcrumb: \(crumb.category) - \(crumb.message ?? "")")
        synchronized(breadcrumbArray) {
            // Ring buffer so adding a breadcrumb stays O(1). The scope owns a snapshot so a caller
            // mutating the breadcrumb afterwards cannot race with a reader of the stored object.
            let snapshot = crumb.snapshotCopy()
            breadcrumbArray[currentBreadcrumbIndex] = snapshot
            currentBreadcrumbIndex = (currentBreadcrumbIndex + 1) % Int(maxBreadcrumbs)
            let serializedBreadcrumb = snapshot.serialize()
            notifyObservers { $0.addSerializedBreadcrumb(serializedBreadcrumb) }
        }
    }

    func deleteBreadcrumbs() {
        synchronized(breadcrumbArray) {
            currentBreadcrumbIndex = 0
            breadcrumbArray.removeAllObjects()
            notifyObservers { $0.clearBreadcrumbs() }
        }
    }

    func storeContext(value: [String: Any], key: String) {
        synchronized(contextDictionary) {
            contextDictionary.setValue(value, forKey: key)
            let contextCopy = contextDictionaryCopy()
            notifyObservers { $0.setContext(contextCopy) }
        }
    }

    func deleteContext(key: String) {
        synchronized(contextDictionary) {
            contextDictionary.removeObject(forKey: key)
            let contextCopy = contextDictionaryCopy()
            notifyObservers { $0.setContext(contextCopy) }
        }
    }

    func storeAttachment(_ attachment: Attachment) {
        synchronized(attachmentArray) {
            attachmentArray.add(attachment)
        }
    }

    func storeAttribute(value: Any, key: String) {
        guard !key.isEmpty else {
            SentrySDKLog.error("Attribute's key cannot be nil nor empty")
            return
        }
        synchronized(attributesDictionary) {
            attributesDictionary[key] = value
            let attributesCopy = anyDictionary(attributesDictionary)
            notifyObservers { $0.setAttributes(attributesCopy) }
        }
    }

    func deleteAttribute(key: String) {
        synchronized(attributesDictionary) {
            attributesDictionary.removeObject(forKey: key)
            let attributesCopy = anyDictionary(attributesDictionary)
            notifyObservers { $0.setAttributes(attributesCopy) }
        }
    }

    func deleteAttachments() {
        synchronized(attachmentArray) {
            attachmentArray.removeAllObjects()
        }
    }

    func resetScope() {
        deleteBreadcrumbs()
        synchronized(tagDictionary) { tagDictionary.removeAllObjects() }
        synchronized(extraDictionary) { extraDictionary.removeAllObjects() }
        synchronized(contextDictionary) {
            contextDictionary.removeAllObjects()
            featureFlagBuffer.removeAll()
        }
        synchronized(fingerprintArray) { fingerprintArray.removeAllObjects() }
        deleteAttachments()
        synchronized(spanLock) { spanStorage = nil }
        synchronized(attributesDictionary) { attributesDictionary.removeAllObjects() }

        synchronized(self) {
            userObject = nil
            userWasSet = true
            userPersistenceCallback?(nil)
        }
        distString = nil
        environmentString = nil
        levelEnum = .none

        notifyObservers { $0.clear() }
    }

    /// Attachments currently stored on the scope.
    @_spi(Private) @objc public var attachments: [Attachment] {
        synchronized(attachmentArray) { objects(of: Attachment.self, in: attachmentArray) }
    }

    /// Attachments captured for a fatal event, such as a screenshot or the view hierarchy.
    @_spi(Private) @objc public var crashReportAttachments: [Attachment] {
        synchronized(crashReportAttachmentArray) { objects(of: Attachment.self, in: crashReportAttachmentArray) }
    }

    /// Adds an attachment captured at crash time so it is sent with that fatal event.
    @_spi(Private)
    @objc(addCrashReportAttachmentInPath:)
    public func addCrashReportAttachment(inPath filePath: String) {
        let attachment: Attachment
        if (filePath as NSString).lastPathComponent == "view-hierarchy.json" {
            attachment = Attachment(
                path: filePath,
                filename: "view-hierarchy.json",
                contentType: "application/json",
                attachmentType: .viewHierarchy
            )
        } else {
            attachment = Attachment(path: filePath)
        }
        synchronized(crashReportAttachmentArray) {
            crashReportAttachmentArray.add(attachment)
        }
    }

    /// Breadcrumbs in chronological order.
    @_spi(Private) @objc public func breadcrumbs() -> [Breadcrumb] {
        synchronized(breadcrumbArray) {
            guard maxBreadcrumbs > 0 else { return [] }
            var crumbs: [Breadcrumb] = []
            for offset in 0 ..< Int(maxBreadcrumbs) {
                let index = (currentBreadcrumbIndex + offset) % Int(maxBreadcrumbs)
                guard index < breadcrumbArray.count, let crumb = breadcrumbArray[index] as? Breadcrumb else {
                    continue
                }
                crumbs.append(crumb)
            }
            return crumbs
        }
    }

    /// Extras currently stored on the scope.
    @_spi(Private) @objc public func extras() -> [String: Any] {
        synchronized(extraDictionary) { anyDictionary(extraDictionary) }
    }

    /// Context currently stored on the scope.
    @_spi(Private) @objc public func context() -> [String: [String: Any]] {
        synchronized(contextDictionary) { contextDictionaryCopy() }
    }

    /// Fingerprints currently stored on the scope.
    @_spi(Private) @objc public func fingerprints() -> [String] {
        synchronized(fingerprintArray) { stringArray(fingerprintArray) }
    }

    /// Returns the context dictionary for one key.
    @_spi(Private)
    @objc(getContextForKey:)
    public func getContextForKey(_ key: String) -> [String: Any]? {
        synchronized(contextDictionary) {
            contextDictionary[key] as? [String: Any]
        }
    }

    /// Runs `block` while holding the breadcrumb lock, so `addBreadcrumb` waits.
    ///
    /// Used to replay existing crumbs and attach an observer without a concurrent crumb being
    /// dropped or inserted ahead of the replay. Callers may re-enter breadcrumb reads.
    @_spi(Private)
    @objc(performWithBreadcrumbsLocked:)
    public func performWithBreadcrumbsLocked(_ block: () -> Void) {
        synchronized(breadcrumbArray) {
            block()
        }
    }
}
