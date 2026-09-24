import Darwin
import Foundation

let directories = Directories.discover()
let defaultConfig = Config(directories: directories)
let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())

do {
    let config = try Config.parse(arguments: arguments, directories: directories)
    try CrashE2ERunner(config: config).run()
} catch is HelpRequested {
    print(usage(defaults: defaultConfig))
    exit(0)
} catch let error as CrashE2EFailure {
    fputs("❌ \(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("❌ \(error)\n", stderr)
    exit(1)
}
