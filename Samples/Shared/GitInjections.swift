import Foundation
import Sentry

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

extension Scope {
    @objc public func injectGitInformation() {
        if let commitHash = Bundle.main.gitCommitHash {
            setTag(value: "\(commitHash)\(Bundle.main.gitStatusClean ? "" : "-dirty")", key: "git-commit-hash")
        }
        if let branchName = Bundle.main.gitBranchName {
            setTag(value: branchName, key: "git-branch-name")
        }
    }
}
