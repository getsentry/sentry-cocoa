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

public func injectGitInformation(scope: Scope) {
    if let commitHash = Bundle.main.gitCommitHash {
        scope.setTag(value: "\(commitHash)\(Bundle.main.gitStatusClean ? "" : "-dirty")", key: "git-commit-hash")
    }
    if let branchName = Bundle.main.gitBranchName {
        scope.setTag(value: branchName, key: "git-branch-name")
    }
}

public class GitInjector: NSObject {
    @objc public static func objc_injectGitInformation(into scope: Scope) {
        injectGitInformation(scope: scope)
    }
}
