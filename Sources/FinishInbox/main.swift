import AppKit
import Darwin
import FinishInboxCore
import Foundation

private struct Arguments {
    let command: String
    let positionals: [String]
    let options: [String: String]
    let flags: Set<String>

    init(_ raw: [String]) throws {
        let knownCommands = ["notify", "map", "unmap", "clear", "status", "doctor", "preview", "manager", "help", "version"]
        var remaining = raw
        if let first = remaining.first, first == "--help" || first == "-h" {
            command = "help"
            remaining.removeFirst()
        } else if let first = remaining.first, first == "--version" {
            command = "version"
            remaining.removeFirst()
        } else if let first = remaining.first, knownCommands.contains(first) {
            command = first
            remaining.removeFirst()
        } else {
            command = "notify"
        }

        var positionals: [String] = []
        var options: [String: String] = [:]
        var flags: Set<String> = []
        var index = 0
        let valueOptions = Set(["--project", "--event-id", "--count", "--directory"])
        let booleanFlags = Set(["--verbose", "--once"])
        while index < remaining.count {
            let argument = remaining[index]
            if valueOptions.contains(argument) {
                guard index + 1 < remaining.count else {
                    throw FinishInboxError.storage("missing value for \(argument)")
                }
                options[argument] = remaining[index + 1]
                index += 2
            } else if booleanFlags.contains(argument) {
                flags.insert(argument)
                index += 1
            } else if argument.hasPrefix("-") {
                throw FinishInboxError.storage("unknown option: \(argument)")
            } else {
                positionals.append(argument)
                index += 1
            }
        }
        self.positionals = positionals
        self.options = options
        self.flags = flags
    }
}

private func stderr(_ value: String) {
    FileHandle.standardError.write(Data((value + "\n").utf8))
}

private func selectedEnvironment() -> [String: String] {
    let keys = [
        "HOME",
        "FINISH_INBOX_HOME",
        "FINISH_INBOX_NO_LAUNCH",
        "FINISH_INBOX_HEADLESS",
        "FINISH_INBOX_APP_PATH",
    ]
    return Dictionary(uniqueKeysWithValues: keys.compactMap { key in
        guard let rawValue = key.withCString({ Darwin.getenv($0) }) else { return nil }
        return (key, String(cString: rawValue))
    })
}

private func launchManagerIfEnabled(environment: [String: String]) throws {
    guard environment["FINISH_INBOX_NO_LAUNCH"] != "1" else { return }
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let process = Process()
    let explicitApp = environment["FINISH_INBOX_APP_PATH"]
        .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
    let bundledApp = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil
    let userHome = environment["HOME"]
        .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.homeDirectoryForCurrentUser
    let installedApp = userHome
        .appendingPathComponent("Applications", isDirectory: true)
        .appendingPathComponent("FinishInbox.app", isDirectory: true)
    let app = [explicitApp, bundledApp, installedApp]
        .compactMap { $0 }
        .first { FileManager.default.fileExists(atPath: $0.path) }

    if let app {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        var openArguments = ["-gnj"]
        for key in ["FINISH_INBOX_HOME", "FINISH_INBOX_HEADLESS"] {
            if let value = environment[key], !value.isEmpty {
                openArguments.append(contentsOf: ["--env", "\(key)=\(value)"])
            }
        }
        openArguments.append(contentsOf: [app.path, "--args", "manager"])
        process.arguments = openArguments
    } else {
        process.executableURL = executable
        process.arguments = ["manager"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
    }
    try process.run()
    if app != nil {
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw FinishInboxError.storage("macOS could not launch the FinishInbox manager")
        }
    }
}

private func printStatus(_ state: ReminderState) {
    if state.counts.isEmpty {
        print("No unread completions.")
        return
    }
    for project in state.counts.keys.sorted() {
        print("\(project)\t\(state.counts[project] ?? 0)")
    }
}

private func printHelp() {
    print("""
    FinishInbox — private local completion reminders for the macOS menu bar

    Usage:
      finish-inbox [notify] [--project LABEL] [--event-id ID] [--directory PATH]
      finish-inbox map <label> [--directory PATH]
      finish-inbox unmap [--directory PATH]
      finish-inbox clear <project>
      finish-inbox status [--verbose]
      finish-inbox doctor [--verbose]
      finish-inbox preview [--project LABEL] [--count COUNT]
      finish-inbox help
      finish-inbox version

    Internal:
      finish-inbox manager [--once]

    Environment:
      FINISH_INBOX_HOME       Override the user home used for private storage.
      FINISH_INBOX_NO_LAUNCH  Set to 1 to queue without launching the manager.
      FINISH_INBOX_HEADLESS   Set to 1 to run the manager without status items.
      FINISH_INBOX_APP_PATH   Override the app bundle used to launch the manager.
    """)
}

private func runDoctor(store: FinishInboxStore, environment: [String: String], verbose: Bool) throws {
    let fm = FileManager.default
    let rootExists = fm.fileExists(atPath: store.paths.root.path)
    let userHome = environment["HOME"]
        .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        ?? fm.homeDirectoryForCurrentUser
    let installedApp = userHome
        .appendingPathComponent("Applications", isDirectory: true)
        .appendingPathComponent("FinishInbox.app", isDirectory: true)
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    print("schema\t\(finishInboxSchemaVersion)")
    print("version\t\(FinishInboxVersion.current)")
    print("cli\t\(fm.isExecutableFile(atPath: executable.path) ? "executable" : "not executable")")
    print("app\t\(fm.fileExists(atPath: installedApp.path) ? "present" : "not installed in ~/Applications")")
    print("storage\t\(rootExists ? "present" : "not created")")
    if rootExists {
        print("root permissions\t\(store.fileMode(at: store.paths.root) == 0o700 ? "private" : "unsafe")")
        for (name, directory) in [("events", store.paths.events), ("quarantine", store.paths.quarantine)] {
            let state = fm.fileExists(atPath: directory.path)
                ? (store.fileMode(at: directory) == 0o700 ? "private" : "unsafe")
                : "missing"
            print("\(name) permissions\t\(state)")
        }
    }
    if fm.fileExists(atPath: store.paths.state.path) {
        _ = try store.loadState()
        print("state\tvalid")
        print("state permissions\t\(store.fileMode(at: store.paths.state) == 0o600 ? "private" : "unsafe")")
    } else {
        print("state\tmissing (empty state)")
    }
    if fm.fileExists(atPath: store.paths.config.path) {
        let config = try store.loadConfig()
        print("config\tvalid (\(config.mappings.count) mappings)")
        print("config permissions\t\(store.fileMode(at: store.paths.config) == 0o600 ? "private" : "unsafe")")
    } else {
        print("config\tmissing (no mappings)")
    }
    if verbose {
        print("cli path\t\(executable.path)")
        print("app path\t\(installedApp.path)")
        print("storage path\t\(store.paths.root.path)")
    }
}

do {
    var rawArguments = Array(CommandLine.arguments.dropFirst())
    if rawArguments.isEmpty && Bundle.main.bundleURL.pathExtension == "app" {
        rawArguments = ["manager"]
    }
    let arguments = try Arguments(rawArguments)
    let environment = selectedEnvironment()
    let store = FinishInboxStore(paths: .fromEnvironment(environment))
    let service = FinishInboxService(store: store)
    let directory = arguments.options["--directory"] ?? FileManager.default.currentDirectoryPath

    switch arguments.command {
    case "help":
        printHelp()
    case "version":
        let version = Bundle.main.object(forInfoDictionaryKey: "FinishInboxVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        print("finish-inbox \(version ?? FinishInboxVersion.current)")
    case "notify":
        guard arguments.positionals.isEmpty else {
            throw FinishInboxError.storage("notify takes no positional arguments")
        }
        let event = try service.notify(
            directory: directory,
            explicitLabel: arguments.options["--project"],
            eventID: arguments.options["--event-id"]
        )
        do {
            try launchManagerIfEnabled(environment: environment)
        } catch {
            stderr("Warning: event \(event.id) is durable, but the manager could not be launched: \(error.localizedDescription)")
        }
    case "map":
        guard arguments.positionals.count == 1 else {
            throw FinishInboxError.storage("usage: finish-inbox map <label>")
        }
        let label = try service.map(directory: directory, to: arguments.positionals[0])
        print("Mapped current directory to \(label).")
    case "unmap":
        guard arguments.positionals.isEmpty else {
            throw FinishInboxError.storage("usage: finish-inbox unmap")
        }
        print(try service.unmap(directory: directory) ? "Mapping removed." : "No exact mapping existed.")
    case "clear":
        guard arguments.positionals.count == 1 else {
            throw FinishInboxError.storage("usage: finish-inbox clear <project>")
        }
        _ = try service.clear(project: arguments.positionals[0])
    case "status":
        guard arguments.positionals.isEmpty else {
            throw FinishInboxError.storage("usage: finish-inbox status")
        }
        let state = try service.status()
        printStatus(state)
        let config = try store.loadConfig()
        print("Mappings: \(config.mappings.count)")
        if arguments.flags.contains("--verbose") {
            for path in config.mappings.keys.sorted() {
                print("\(path)\t\(config.mappings[path] ?? "")")
            }
        }
    case "doctor":
        try runDoctor(
            store: store,
            environment: environment,
            verbose: arguments.flags.contains("--verbose")
        )
    case "preview":
        guard arguments.positionals.isEmpty else {
            throw FinishInboxError.storage("usage: finish-inbox preview [--project label] [--count count]")
        }
        let project = try InputValidation.normalizeLabel(arguments.options["--project"] ?? "杂")
        guard let count = Int(arguments.options["--count"] ?? "1"), count > 0 else {
            throw FinishInboxError.storage("count must be a positive integer")
        }
        print(DisplayFormatting.menuBarLabel(project: project, count: count))
    case "manager":
        guard arguments.positionals.isEmpty else {
            throw FinishInboxError.storage("usage: finish-inbox manager [--once]")
        }
        runManager(
            service: service,
            headless: environment["FINISH_INBOX_HEADLESS"] == "1",
            runOnce: arguments.flags.contains("--once")
        )
    default:
        fatalError("unreachable")
    }
} catch {
    stderr(error.localizedDescription)
    exit(EXIT_FAILURE)
}
