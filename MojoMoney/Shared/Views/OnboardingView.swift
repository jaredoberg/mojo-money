import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                OnboardingStep1(onNext: { step = 1 })
                    .tag(0)
                OnboardingStep2(onNext: { step = 2 })
                    .environmentObject(appState)
                    .tag(1)
                OnboardingStep3 {
                    appState.completeOnboarding()
                }
                .environmentObject(appState)
                .tag(2)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            .tabViewStyle(.automatic)
            #endif

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.mojoTeal : Color.mojoTextSecondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.bottom, MOJOSpacing.lg)
        }
        .background(Color.mojoNavy.ignoresSafeArea())
    }
}

// MARK: - Step 1: Welcome

struct OnboardingStep1: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: MOJOSpacing.lg) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.mojoTeal)
                    .frame(width: 100, height: 100)
                Text("M⚡")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(.white)
            }

            VStack(spacing: MOJOSpacing.sm) {
                Text("MOJO Money")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Monarch, on autopilot.")
                    .font(.title3)
                    .foregroundColor(.mojoTeal)
            }

            Text("Extend Monarch Money with powerful automation modules. Import receipts, enrich transactions, track project costs — all synced back to Monarch automatically.")
                .font(.body)
                .foregroundColor(.mojoTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Spacer()

            MOJOButton(title: "Get Started →", style: .primary, action: onNext)
                .padding(.bottom, MOJOSpacing.md)
        }
        .padding(.horizontal, MOJOSpacing.xl)
    }
}

// MARK: - Step 2: Connect Monarch

struct OnboardingStep2: View {
    @EnvironmentObject var appState: AppState
    let onNext: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var mfaToken = ""
    @State private var isConnecting = false
    @State private var errorMessage: String? = nil
    @State private var isConnected = false

    var body: some View {
        VStack(spacing: MOJOSpacing.lg) {
            Spacer()

            VStack(spacing: MOJOSpacing.sm) {
                Text("Connect Monarch")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Your credentials are stored securely in your Keychain and never leave your device.")
                    .font(.caption)
                    .foregroundColor(.mojoTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            VStack(spacing: MOJOSpacing.sm) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                TextField("MFA Token (if enabled)", text: $mfaToken)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 360)

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.mojoDestructive)
                    .frame(maxWidth: 360)
            }

            Text("If you use Google SSO, set a password in Monarch Settings → Security first.")
                .font(.caption2)
                .foregroundColor(.mojoTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.mojoSuccess)
                    Text("Connected!")
                        .foregroundColor(.mojoSuccess)
                        .fontWeight(.semibold)
                }
            } else {
                MOJOButton(title: "Connect", style: .primary, isLoading: isConnecting) {
                    Task { await connect() }
                }
            }

            Spacer()

            if isConnected {
                MOJOButton(title: "Continue →", style: .primary, action: onNext)
                    .padding(.bottom, MOJOSpacing.md)
            } else {
                MOJOButton(title: "Skip for now", style: .ghost, action: onNext)
                    .padding(.bottom, MOJOSpacing.md)
            }
        }
        .padding(.horizontal, MOJOSpacing.xl)
    }

    func connect() async {
        errorMessage = nil
        isConnecting = true
        do {
            try await appState.monarchService.authenticate(
                email: email, password: password,
                mfaToken: mfaToken.isEmpty ? nil : mfaToken
            )
            isConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isConnecting = false
    }
}

// MARK: - Step 3: Choose Module

struct OnboardingStep3: View {
    @EnvironmentObject var appState: AppState
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: MOJOSpacing.lg) {
            Spacer()

            VStack(spacing: MOJOSpacing.sm) {
                Text("Choose Your Module")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Start with HD Sync to enrich your Home Depot transactions.")
                    .font(.subheadline)
                    .foregroundColor(.mojoTextSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: MOJOSpacing.sm) {
                ForEach(appState.moduleRegistry.modules, id: \.id) { mod in
                    HStack(spacing: 12) {
                        Image(systemName: mod.icon)
                            .font(.title3)
                            .foregroundColor(mod.isEnabled ? mod.accentColor : .mojoTextSecondary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mod.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(mod.isEnabled ? .primary : .mojoTextSecondary)
                            Text(mod.isEnabled ? "Available" : "Coming Soon")
                                .font(.caption)
                                .foregroundColor(mod.isEnabled ? .mojoSuccess : .mojoTextSecondary)
                        }
                        Spacer()
                        if mod.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.mojoSuccess)
                        }
                    }
                    .padding(MOJOSpacing.md)
                    .background(mod.isEnabled ? Color.mojoCard : Color.mojoCard.opacity(0.5))
                    .cornerRadius(MOJORadius.md)
                }
            }
            .frame(maxWidth: 380)

            Spacer()

            MOJOButton(title: "Open HD Sync →", style: .primary, action: onFinish)
                .padding(.bottom, MOJOSpacing.md)
        }
        .padding(.horizontal, MOJOSpacing.xl)
    }
}
