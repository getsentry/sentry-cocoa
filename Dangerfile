message("Hello, I'm working :)")

declared_trivial = github.pr_title.include? "#trivial"

warn("PR is classed as Work in Progress") if github.pr_title.include? "[WIP]"
warn("Big PR") if git.lines_of_code > 500

swiftlint.lint_files inline_mode: true
