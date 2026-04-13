import Foundation

/// Thin Swift layer — actual Monarch API calls are made by the Python backend.
/// This service manages session state and provides convenience async wrappers.
@MainActor
final class MonarchService: ObservableObject {
    static let shared = MonarchService()

    @Published var isConnected = false
    @Published var sessionToken: String? = nil

    init() {
        sessionToken = KeychainService.shared.getSessionToken()
        isConnected  = sessionToken != nil
    }

    // MARK: - Authentication

    struct AuthResult: Decodable {
        let session_token: String
        let user_email: String?
    }

    func authenticate(email: String, password: String, mfaToken: String? = nil) async throws {
        var payload: [String: Any] = ["email": email, "password": password]
        if let mfa = mfaToken, !mfa.isEmpty { payload["mfa_token"] = mfa }

        let result: AuthResult = try await PythonBridge.shared.run(
            module: "shared",
            action: "authenticate",
            payload: payload
        )
        sessionToken = result.session_token
        _ = KeychainService.shared.saveSessionToken(result.session_token)
        _ = KeychainService.shared.saveMonarchCredentials(email: email, password: password)
        isConnected = true
    }

    func disconnect() {
        sessionToken = nil
        isConnected  = false
        KeychainService.shared.deleteSessionToken()
        KeychainService.shared.deleteMonarchCredentials()
    }

    // MARK: - Helpers

    func requireSession() throws -> String {
        guard let token = sessionToken else {
            throw MonarchError.notAuthenticated
        }
        return token
    }
}

enum MonarchError: LocalizedError {
    case notAuthenticated
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not connected to Monarch. Please authenticate in Settings."
        }
    }
}
