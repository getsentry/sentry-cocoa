import Foundation
import Sentry

extension Bundle {
    var gitCommitHash: String? {
        infoDictionary?["GIT_COMMIT_HASH"] as? String
    }
    var gitBranchName: String {
        (infoDictionary?["GIT_BRANCH"] as? String) ?? "(detached)"
    }
    var gitStatusClean: Bool {
        (infoDictionary?["GIT_STATUS_CLEAN"] as? NSNumber)?.boolValue ?? false
    }
}

extension Scope {
    func injectGitInformation() {
        if let commitHash = Bundle.main.gitCommitHash {
            setTag(value: "\(commitHash)\(Bundle.main.gitStatusClean ? "" : "-dirty")", key: "git-commit-hash")
        }
        
        setTag(value: Bundle.main.gitBranchName, key: "git-branch-name")
        }
}
