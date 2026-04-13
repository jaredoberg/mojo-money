import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var mfaToken = ""
    @State private var isConnecting = false
    @State private var connectMessage: (text: String, isError: Bool)? = nil

    @State private var pythonVerifyResult: String? = nil
    @State private var isVerifyingPython = false
    @State private var showInstallSheet = false

    @AppStorage("projectRoot")      private var projectRoot      = PythonBridge.detectProjectRoot()
    // detectPython resolves after projectRoot so we read it lazily in loadCredentials
    @AppStorage("pythonExecutable") private var pythonExecutable = ""

    var body: some View {
        Form {
            // MARK: Monarch Section
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isMonarchConnected ? Color.mojoSuccess : Color.mojoDestructive)
                            .frame(width: 8, height: 8)
                        Text(appState.isMonarchConnected ? "Connected" : "Disconnected")
                            .foregroundColor(appState.isMonarchConnected ? .mojoSuccess : .mojoDestructive)
                    }
                }

                TextField("Email", text: $email)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                SecureField("Password", text: $password)
                TextField("MFA Token (ephemeral)", text: $mfaToken)

                if let msg = connectMessage {
                    Text(msg.text)
                        .font(.caption)
                        .foregroundColor(msg.isError ? .mojoDestructive : .mojoSuccess)
                }

                Text("Requires Monarch password login. If you use Google SSO, set a password in Monarch Settings → Security first.")
                    .font(.caption)
                    .foregroundColor(.mojoTextSecondary)

                HStack {
                    MOJOButton(title: "Connect", style: .primary, isLoading: isConnecting) {
                        Task { await connectMonarch() }
                    }
                    if appState.isMonarchConnected {
                        MOJOButton(title: "Disconnect", style: .destructive) {
                            appState.monarchService.disconnect()
                        }
                    }
                }
            } header: {
                Text("Monarch Money")
            }

            // MARK: Python Section
            Section {
                LabeledContent("Python Path") {
                    TextField("e.g. /opt/homebrew/bin/python3", text: $pythonExecutable)
                        .frame(maxWidth: 260)
                }
                LabeledContent("Project Root") {
                    TextField("e.g. /Users/you/Repos/mojo-money", text: $projectRoot)
                        .frame(maxWidth: 260)
                }

                if let result = pythonVerifyResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.contains("OK") ? .mojoSuccess : .mojoDestructive)
                }

                HStack {
                    MOJOButton(title: "Verify Environment", style: .secondary, isLoading: isVerifyingPython) {
                        Task { await verifyPython() }
                    }
                    MOJOButton(title: "Install Dependencies", style: .ghost) {
                        showInstallSheet = true
                    }
                }
            } header: {
                Text("Python Environment")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear(perform: loadCredentials)
        .sheet(isPresented: $showInstallSheet) {
            InstallDepsSheet(
                projectRoot: projectRoot,
                systemPython: PythonBridge.detectPython(projectRoot: ""),
                pythonExecutable: $pythonExecutable
            )
        }
    }

    func loadCredentials() {
        if let creds = KeychainService.shared.getMonarchCredentials() {
            email = creds.email
        }
        // Resolve projectRoot first
        if projectRoot.isEmpty {
            projectRoot = PythonBridge.detectProjectRoot()
        }
        // Always prefer the venv python if it exists — the stored value may point
        // to system python from an earlier launch before the venv was created.
        let venvPython = "\(projectRoot)/python/.venv/bin/python3"
        if FileManager.default.fileExists(atPath: venvPython) {
            pythonExecutable = venvPython
        } else if pythonExecutable.isEmpty {
            pythonExecutable = PythonBridge.detectPython(projectRoot: projectRoot)
        }
        // Sync into the shared bridge — it initializes once at app launch
        // before these UserDefaults keys exist, so push updates now.
        PythonBridge.shared.projectRoot      = projectRoot
        PythonBridge.shared.pythonExecutable = pythonExecutable
    }

    func connectMonarch() async {
        connectMessage = nil
        isConnecting = true
        PythonBridge.shared.projectRoot      = projectRoot
        PythonBridge.shared.pythonExecutable = pythonExecutable
        do {
            try await appState.monarchService.authenticate(
                email: email, password: password,
                mfaToken: mfaToken.isEmpty ? nil : mfaToken
            )
            connectMessage = ("Connected successfully!", false)
            mfaToken = ""
        } catch {
            connectMessage = (error.localizedDescription, true)
        }
        isConnecting = false
    }

    func verifyPython() async {
        isVerifyingPython = true
        pythonVerifyResult = nil
        let bridge = PythonBridge.shared
        bridge.pythonExecutable = pythonExecutable
        bridge.projectRoot = projectRoot
        let (output, success) = await bridge.runRaw(arguments: ["-c", "import monarchmoney; print('OK — monarchmoney installed')"])
        pythonVerifyResult = success ? output : "Error: \(output)"
        isVerifyingPython = false
    }
}

// MARK: - Install Dependencies Sheet

struct InstallDepsSheet: View {
    let projectRoot: String
    let systemPython: String          // fallback if venv doesn't exist yet
    @Binding var pythonExecutable: String  // updated to venv path on success
    @Environment(\.dismiss) private var dismiss
    @State private var output = ""
    @State private var isRunning = false
    @State private var isDone = false
    @State private var installedVenvPath = ""

    var venvPython: String { "\(projectRoot)/python/.venv/bin/python3" }
    var venvExists: Bool { FileManager.default.fileExists(atPath: venvPython) }

    var body: some View {
        VStack(alignment: .leading, spacing: MOJOSpacing.md) {
            HStack {
                Text("Install Dependencies")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .disabled(isRunning)
            }

            Text(venvExists
                 ? "Updating venv at \(projectRoot)/python/.venv"
                 : "Creating venv + installing into \(projectRoot)/python/.venv")
                .font(.caption)
                .foregroundColor(.mojoTextSecondary)

            ScrollView {
                Text(output.isEmpty ? "Starting..." : output)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.mojoSuccess)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(MOJOSpacing.sm)
            }
            .background(Color.mojoNavy)
            .cornerRadius(MOJORadius.sm)
            .frame(minHeight: 200)

            if isDone {
                if !installedVenvPath.isEmpty {
                    Text("Python path updated to venv.")
                        .font(.caption).foregroundColor(.mojoSuccess)
                }
                MOJOButton(title: "Done", style: .primary) { dismiss() }
            }
        }
        .padding(MOJOSpacing.lg)
        .frame(minWidth: 480)
        .task { await runInstall() }
    }

    func runInstall() async {
        isRunning = true
        let reqPath    = "\(projectRoot)/python/requirements.txt"
        let venvDir    = "\(projectRoot)/python/.venv"

        var log = ""

        func run(_ executable: String, _ args: [String]) -> Bool {
            let p = Process()
            let pipe = Pipe()
            p.executableURL  = URL(fileURLWithPath: executable)
            p.arguments      = args
            p.standardOutput = pipe
            p.standardError  = pipe
            try? p.run()
            p.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            log += out + "\n"
            DispatchQueue.main.async { output = log }
            return p.terminationStatus == 0
        }

        // Step 1: create venv if needed
        if !FileManager.default.fileExists(atPath: venvPython) {
            log += "Creating venv...\n"
            DispatchQueue.main.async { output = log }
            _ = run(systemPython, ["-m", "venv", venvDir])
        }

        // Step 2: install requirements into venv
        log += "Installing requirements...\n"
        DispatchQueue.main.async { output = log }
        let ok = run(venvPython, ["-m", "pip", "install", "-r", reqPath])

        if ok && FileManager.default.fileExists(atPath: venvPython) {
            installedVenvPath = venvPython
            DispatchQueue.main.async {
                pythonExecutable = venvPython
                UserDefaults.standard.set(venvPython, forKey: "pythonExecutable")
                PythonBridge.shared.pythonExecutable = venvPython
            }
        }

        isRunning = false
        isDone    = true
    }
}
