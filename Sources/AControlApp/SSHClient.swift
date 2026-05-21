import Foundation

actor SSHClient {
    nonisolated func run(_ launchPath: String = "/usr/bin/env", _ arguments: [String], input: Data? = nil, timeout: TimeInterval = 120) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments

                let fileManager = FileManager.default
                let outURL = fileManager.temporaryDirectory
                    .appendingPathComponent("acontrol-stdout-\(UUID().uuidString)")
                let errURL = fileManager.temporaryDirectory
                    .appendingPathComponent("acontrol-stderr-\(UUID().uuidString)")
                fileManager.createFile(atPath: outURL.path, contents: nil)
                fileManager.createFile(atPath: errURL.path, contents: nil)
                guard let stdout = try? FileHandle(forWritingTo: outURL),
                      let stderr = try? FileHandle(forWritingTo: errURL) else {
                    continuation.resume(returning: CommandResult(exitCode: 127, output: "", error: "Could not create command output files"))
                    return
                }
                defer {
                    try? stdout.close()
                    try? stderr.close()
                    try? fileManager.removeItem(at: outURL)
                    try? fileManager.removeItem(at: errURL)
                }
                process.standardOutput = stdout
                process.standardError = stderr
                if let input {
                    let stdin = Pipe()
                    process.standardInput = stdin
                    do {
                        try process.run()
                        stdin.fileHandleForWriting.write(input)
                        try? stdin.fileHandleForWriting.close()
                    } catch {
                        continuation.resume(returning: CommandResult(exitCode: 127, output: "", error: error.localizedDescription))
                        return
                    }
                } else {
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(returning: CommandResult(exitCode: 127, output: "", error: error.localizedDescription))
                        return
                    }
                }

                func runSignalTool(_ launchPath: String, _ arguments: [String]) {
                    let signalProcess = Process()
                    signalProcess.executableURL = URL(fileURLWithPath: launchPath)
                    signalProcess.arguments = arguments
                    signalProcess.standardOutput = FileHandle.nullDevice
                    signalProcess.standardError = FileHandle.nullDevice
                    do {
                        try signalProcess.run()
                        signalProcess.waitUntilExit()
                    } catch {
                        // Best-effort cleanup only; the original command result remains authoritative.
                    }
                }

                func stopProcessTree(signal: String) {
                    let pid = "\(process.processIdentifier)"
                    let script = """
                    killtree() {
                      local parent="$1"
                      local child
                      for child in $(/usr/bin/pgrep -P "$parent" 2>/dev/null); do
                        killtree "$child"
                        /bin/kill -\(signal) "$child" 2>/dev/null || true
                      done
                    }
                    killtree \(pid)
                    /bin/kill -\(signal) \(pid) 2>/dev/null || true
                    """
                    runSignalTool("/bin/bash", ["-c", script])
                }

                var didTimeout = false
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if process.isRunning {
                    didTimeout = true
                    stopProcessTree(signal: "TERM")
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.5)
                    if process.isRunning {
                        process.interrupt()
                        stopProcessTree(signal: "KILL")
                    }
                }

                process.waitUntilExit()
                try? stdout.close()
                try? stderr.close()
                let outData = (try? Data(contentsOf: outURL)) ?? Data()
                let errData = (try? Data(contentsOf: errURL)) ?? Data()
                let output = String(data: outData, encoding: .utf8) ?? ""
                var error = String(data: errData, encoding: .utf8) ?? ""
                if didTimeout {
                    let message = "Command timed out after \(Int(timeout))s and was stopped. Child transfer processes were also asked to terminate."
                    error = [error, message].filter { !$0.isEmpty }.joined(separator: "\n")
                }
                continuation.resume(returning: CommandResult(exitCode: didTimeout ? 124 : process.terminationStatus, output: output, error: error))
            }
        }
    }

    nonisolated func remote(settings: AppSettings, action: String, args: [String] = [], input: String? = nil, timeout: TimeInterval = 120, environment: [String: String] = [:]) async -> CommandResult {
        guard settings.hasSSHTarget else {
            return CommandResult(exitCode: 64, output: "", error: "Configure an SSH target in Settings.")
        }
        let dynamicEnvironment = environment.keys.sorted()
            .compactMap { key -> String? in
                guard let value = environment[key], !value.trimmed.isEmpty else { return nil }
                return "\(key)=\(value.shellQuoted)"
            }
            .joined(separator: " ")
        let environmentPrefix = [settings.remoteToolEnvironment.trimmed, dynamicEnvironment]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let command = "\(environmentPrefix.isEmpty ? "" : environmentPrefix + " ")\(settings.remoteScript) \(action) \(args.map(\.shellQuoted).joined(separator: " "))"
        return await run(
            "/usr/bin/ssh",
            ["-T"] + settings.sshProcessOptions + [settings.sshTarget, command],
            input: input?.data(using: .utf8),
            timeout: timeout
        )
    }

    nonisolated func remoteToFile(
        settings: AppSettings,
        action: String,
        args: [String] = [],
        input: String? = nil,
        outputURL: URL,
        timeout: TimeInterval = 120,
        environment: [String: String] = [:]
    ) async -> CommandResult {
        guard settings.hasSSHTarget else {
            return CommandResult(exitCode: 64, output: "", error: "Configure an SSH target in Settings.")
        }
        let dynamicEnvironment = environment.keys.sorted()
            .compactMap { key -> String? in
                guard let value = environment[key], !value.trimmed.isEmpty else { return nil }
                return "\(key)=\(value.shellQuoted)"
            }
            .joined(separator: " ")
        let environmentPrefix = [settings.remoteToolEnvironment.trimmed, dynamicEnvironment]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let command = "\(environmentPrefix.isEmpty ? "" : environmentPrefix + " ")\(settings.remoteScript) \(action) \(args.map(\.shellQuoted).joined(separator: " "))"

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                process.arguments =
                    ["-T"] + settings.sshProcessOptions + ["-o", "Compression=no"]
                    + [settings.sshTarget, command]

                let fileManager = FileManager.default
                do {
                    try fileManager.createDirectory(
                        at: outputURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    fileManager.createFile(atPath: outputURL.path, contents: nil)
                } catch {
                    continuation.resume(
                        returning: CommandResult(
                            exitCode: 74, output: "", error: error.localizedDescription))
                    return
                }

                let errURL = fileManager.temporaryDirectory
                    .appendingPathComponent("acontrol-stderr-\(UUID().uuidString)")
                fileManager.createFile(atPath: errURL.path, contents: nil)
                guard let stdout = try? FileHandle(forWritingTo: outputURL),
                      let stderr = try? FileHandle(forWritingTo: errURL) else {
                    continuation.resume(
                        returning: CommandResult(
                            exitCode: 127, output: "",
                            error: "Could not create command output files"))
                    return
                }
                defer {
                    try? stdout.close()
                    try? stderr.close()
                    try? fileManager.removeItem(at: errURL)
                }
                process.standardOutput = stdout
                process.standardError = stderr
                if let input {
                    let stdin = Pipe()
                    process.standardInput = stdin
                    do {
                        try process.run()
                        stdin.fileHandleForWriting.write(Data(input.utf8))
                        try? stdin.fileHandleForWriting.close()
                    } catch {
                        continuation.resume(
                            returning: CommandResult(
                                exitCode: 127, output: "", error: error.localizedDescription))
                        return
                    }
                } else {
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(
                            returning: CommandResult(
                                exitCode: 127, output: "", error: error.localizedDescription))
                        return
                    }
                }

                func runSignalTool(_ launchPath: String, _ arguments: [String]) {
                    let signalProcess = Process()
                    signalProcess.executableURL = URL(fileURLWithPath: launchPath)
                    signalProcess.arguments = arguments
                    signalProcess.standardOutput = FileHandle.nullDevice
                    signalProcess.standardError = FileHandle.nullDevice
                    do {
                        try signalProcess.run()
                        signalProcess.waitUntilExit()
                    } catch {
                        // Best-effort cleanup only; the original command result remains authoritative.
                    }
                }

                func stopProcessTree(signal: String) {
                    let pid = "\(process.processIdentifier)"
                    let script = """
                    killtree() {
                      local parent="$1"
                      local child
                      for child in $(/usr/bin/pgrep -P "$parent" 2>/dev/null); do
                        killtree "$child"
                        /bin/kill -\(signal) "$child" 2>/dev/null || true
                      done
                    }
                    killtree \(pid)
                    /bin/kill -\(signal) \(pid) 2>/dev/null || true
                    """
                    runSignalTool("/bin/bash", ["-c", script])
                }

                var didTimeout = false
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if process.isRunning {
                    didTimeout = true
                    stopProcessTree(signal: "TERM")
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.5)
                    if process.isRunning {
                        process.interrupt()
                        stopProcessTree(signal: "KILL")
                    }
                }

                process.waitUntilExit()
                try? stdout.close()
                try? stderr.close()
                let errData = (try? Data(contentsOf: errURL)) ?? Data()
                var error = String(data: errData, encoding: .utf8) ?? ""
                if didTimeout {
                    let message = "Command timed out after \(Int(timeout))s and was stopped. Child transfer processes were also asked to terminate."
                    error = [error, message].filter { !$0.isEmpty }.joined(separator: "\n")
                }
                continuation.resume(
                    returning: CommandResult(
                        exitCode: didTimeout ? 124 : process.terminationStatus, output: "", error: error))
            }
        }
    }

    nonisolated func shell(_ script: String, timeout: TimeInterval = 3600) async -> CommandResult {
        await run("/bin/zsh", ["-lc", script], timeout: timeout)
    }
}
