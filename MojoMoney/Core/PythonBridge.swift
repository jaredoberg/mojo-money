import Foundation

// MARK: - Response envelope

struct BridgeResponse<T: Decodable>: Decodable {
    let success: Bool
    let action: String?
    let data: T?
    let error: String?
}

// MARK: - Errors

enum PythonBridgeError: LocalizedError {
    case pythonNotFound
    case runnerNotFound(String)
    case executionFailed(String)
    case notSupportedOnPlatform

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:           return "Python 3 not found. Set the path in Settings."
        case .runnerNotFound(let p):    return "mojo_runner.py not found at: \(p)"
        case .executionFailed(let m):   return m
        case .notSupportedOnPlatform:   return "Python subprocess not supported on this platform."
        }
    }
}

// MARK: - Bridge

@MainActor
final class PythonBridge: ObservableObject {
    static let shared = PythonBridge()

    @Published var pythonExecutable: String
    @Published var projectRoot: String   // directory that contains python/

    init() {
        let root = UserDefaults.standard.string(forKey: "projectRoot") ?? PythonBridge.detectProjectRoot()
        projectRoot      = root
        // Prefer stored value; if none, detect with venv awareness
        pythonExecutable = UserDefaults.standard.string(forKey: "pythonExecutable") ?? PythonBridge.detectPython(projectRoot: root)
    }

    var runnerPath: String { "\(projectRoot)/python/mojo_runner.py" }

    // MARK: - Public API

    func run<T: Decodable>(module: String, action: String, payload: [String: Any]) async throws -> T {
        #if os(iOS)
        throw PythonBridgeError.notSupportedOnPlatform
        #else
        guard !pythonExecutable.isEmpty else { throw PythonBridgeError.pythonNotFound }

        let runner = runnerPath
        guard FileManager.default.fileExists(atPath: runner) else {
            throw PythonBridgeError.runnerNotFound(runner)
        }

        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let payloadURL  = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mojo_\(UUID().uuidString).json")
        try payloadData.write(to: payloadURL)
        defer { try? FileManager.default.removeItem(at: payloadURL) }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL    = URL(fileURLWithPath: pythonExecutable)
        process.arguments        = [runner, "--module", module, "--action", action, "--payload", payloadURL.path]
        process.standardOutput   = stdoutPipe
        process.standardError    = stderrPipe

        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = "\(projectRoot)/python:\(env["PYTHONPATH"] ?? "")"
        process.environment = env

        try process.run()

        return try await withCheckedThrowingContinuation { cont in
            process.terminationHandler = { _ in
                let outData  = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData  = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr   = String(data: errData, encoding: .utf8) ?? ""

                do {
                    let resp = try JSONDecoder().decode(BridgeResponse<T>.self, from: outData)
                    if resp.success, let result = resp.data {
                        cont.resume(returning: result)
                    } else {
                        let msg = resp.error ?? (errStr.isEmpty ? "Unknown error" : errStr)
                        cont.resume(throwing: PythonBridgeError.executionFailed(msg))
                    }
                } catch {
                    let raw = String(data: outData, encoding: .utf8) ?? "(empty)"
                    cont.resume(throwing: PythonBridgeError.executionFailed(
                        "JSON parse error: \(error.localizedDescription)\nOutput: \(raw)\nStderr: \(errStr)"
                    ))
                }
            }
        }
        #endif
    }

    /// Run a quick subprocess and return stdout as a String.
    func runRaw(arguments: [String]) async -> (output: String, success: Bool) {
        #if os(iOS)
        return ("Not supported on iOS", false)
        #else
        return await withCheckedContinuation { cont in
            let process = Process()
            let pipe    = Pipe()
            process.executableURL  = URL(fileURLWithPath: pythonExecutable)
            process.arguments      = arguments
            process.standardOutput = pipe
            process.standardError  = pipe
            do {
                try process.run()
                process.terminationHandler = { p in
                    let data   = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    cont.resume(returning: (output, p.terminationStatus == 0))
                }
            } catch {
                cont.resume(returning: (error.localizedDescription, false))
            }
        }
        #endif
    }

    // MARK: - Auto-detection

    /// Returns the best Python executable to use.
    /// Prefers the venv inside the project root (which has monarchmoney installed),
    /// falling back to system Python.
    static func detectPython(projectRoot: String = "") -> String {
        // Check venv first — this has monarchmoney installed
        let root = projectRoot.isEmpty ? detectProjectRoot() : projectRoot
        if !root.isEmpty {
            let venvPython = "\(root)/python/.venv/bin/python3"
            if FileManager.default.fileExists(atPath: venvPython) {
                return venvPython
            }
        }
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
            "/usr/local/bin/python3"
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return "/usr/bin/python3"
    }

    static func detectProjectRoot() -> String {
        // Walk up from bundle looking for python/mojo_runner.py
        var url = Bundle.main.bundleURL
        for _ in 0..<8 {
            url = url.deletingLastPathComponent()
            let candidate = url.appendingPathComponent("python/mojo_runner.py").path
            if FileManager.default.fileExists(atPath: candidate) {
                return url.path
            }
        }
        // Last resort: bundle resource path
        if let rp = Bundle.main.resourcePath {
            let candidate = "\(rp)/python/mojo_runner.py"
            if FileManager.default.fileExists(atPath: candidate) {
                return rp
            }
        }
        return ""
    }
}
