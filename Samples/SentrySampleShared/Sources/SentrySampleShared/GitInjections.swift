import Foundation
import SentryObjC
import SentrySwift

extension Bundle {
    var gitCommitHash: String? {
        infoDictionary?["GIT_COMMIT_HASH"] as? String
    }
    var gitBranchName: String? {
        infoDictionary?["GIT_BRANCH"] as? String
    }
    var gitStatusClean: Bool {
        (infoDictionary?["GIT_STATUS_CLEAN"] as? String) == "1"
    }
}

private func gitInformationTags() -> [String: String] {
    var tags: [String: String] = [:]
    if let commitHash = Bundle.main.gitCommitHash {
        tags["git-commit-hash"] = "\(commitHash)\(Bundle.main.gitStatusClean ? "" : "-dirty")"
    }
    if let branchName = Bundle.main.gitBranchName {
        tags["git-branch-name"] = branchName
    }
    return tags
}

public func injectGitInformation(scope: Scope) {
    for (key, value) in gitInformationTags() {
        scope.setTag(value: value, key: key)
    }
}

public class GitInjector: NSObject {
    @objc public static func objc_injectGitInformation(into scope: SentryObjCScope) {
        for (key, value) in gitInformationTags() {
            scope.setTagValue(value, forKey: key)
        }
    }
}
