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

    @AppStorage("pythonExecutable") private var pythonExecutable = PythonBridge.detectPython()
    @AppStorage("projectRoot")      private var projectRoot      = PythonBridge.detectProjectRoot()

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
            InstallDepsSheet(projectRoot: projectRoot, pythonExecutable: pythonExecutable)
        }
    }

    func loadCredentials() {
        if let creds = KeychainService.shared.getMonarchCredentials() {
            email = creds.email
        }
        pythonExecutable = UserDefaults.standard.string(forKey: "pythonExecutable") ?? PythonBridge.detectPython()
        projectRoot      = UserDefaults.standard.string(forKey: "projectRoot")      ?? PythonBridge.detectProjectRoot()
    }

    func connectMonarch() async {
        connectMessage = nil
        isConnecting = true
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
        let (output, success) = await bridge.runRaw(arguments: ["-c", "import monarchmoney; print('OK — monarchmoney installed')"])
        pythonVerifyResult = success ? output : "Error: \(output)"
        isVerifyingPython = false
    }
}

// MARK: - Install Dependencies Sheet

struct InstallDepsSheet: View {
    let projectRoot: String
    let pythonExecutable: String
    @Environment(\.dismiss) private var dismiss
    @State private var output = ""
    @State private var isRunning = false
    @State private var isDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: MOJOSpacing.md) {
            HStack {
                Text("Install Dependencies")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .disabled(isRunning)
            }

            Text("Running: \(pythonExecutable) -m pip install -r requirements.txt")
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
                MOJOButton(title: "Done", style: .primary) { dismiss() }
            }
        }
        .padding(MOJOSpacing.lg)
        .frame(minWidth: 480)
        .task { await runInstall() }
    }

    func runInstall() async {
        isRunning = true
        let reqPath = "\(projectRoot)/python/requirements.txt"
        let process = Process()
        let pipe    = Pipe()
        process.executableURL    = URL(fileURLWithPath: pythonExecutable)
        process.arguments        = ["-m", "pip", "install", "-r", reqPath]
        process.standardOutput   = pipe
        process.standardError    = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        output   = String(data: data, encoding: .utf8) ?? "Done."
        isRunning = false
        isDone    = true
    }
}
