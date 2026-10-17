import Foundation
import Observation

/// Email → 6-digit code → nickname (first time only) → signed in.
@Observable @MainActor final class AccountViewModel {
    enum Step: Equatable { case email, code, nickname, signedIn }

    private(set) var step: Step
    var email = ""
    var code = ""
    var nickname = ""
    private(set) var isWorking = false
    private(set) var error: String?
    private(set) var blocked: [BlockedUser] = []

    private let auth: AuthService

    init(auth: AuthService = SupabaseAuthService()) {
        self.auth = auth
        if let email = auth.signedInEmail {
            self.email = email
            step = .signedIn
        } else {
            step = .email
        }
    }

    var isSignedIn: Bool { step == .signedIn }

    /// After a relaunch: loads my nickname, or asks for one if I quit before choosing it.
    func restore() async {
        guard step == .signedIn, nickname.isEmpty else { return }
        await run {
            if let saved = try await auth.nickname() { nickname = saved } else { step = .nickname }
        }
    }

    func sendCode() async {
        email = email.trimmingCharacters(in: .whitespaces)
        guard email.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) != nil else {
            error = "Cette adresse email n'est pas valide."
            return
        }
        await run {
            try await auth.sendCode(to: email)
            code = ""
            step = .code
        }
    }

    func verify() async {
        await run {
            try await auth.verify(email: email, code: code)
            if let saved = try await auth.nickname() {
                nickname = saved
                step = .signedIn
            } else {
                step = .nickname
            }
        }
    }

    func saveNickname() async {
        nickname = nickname.trimmingCharacters(in: .whitespaces)
        guard (3...20).contains(nickname.count) else {
            error = "Ton pseudo doit faire entre 3 et 20 caractères."
            return
        }
        await run {
            try await auth.setNickname(nickname)
            step = .signedIn
        }
    }

    func changeEmail() {
        error = nil
        step = .email
    }

    func signOut() async {
        await run {
            try await auth.signOut()
            email = ""
            nickname = ""
            blocked = []
            step = .email
        }
    }

    func loadBlocks() async {
        guard isSignedIn else { return }
        await run { blocked = try await auth.blockedUsers() }
    }

    /// True once blocked, so the caller can reload the comments.
    func block(_ userID: UUID) async -> Bool {
        await run {
            try await auth.block(userID)
            blocked = try await auth.blockedUsers()
        }
    }

    func unblock(_ user: BlockedUser) async {
        await run {
            try await auth.unblock(user.id)
            blocked.removeAll { $0.id == user.id }
        }
    }

    @discardableResult private func run(_ work: () async throws -> Void) async -> Bool {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch AuthFailure.invalidEmail {
            error = "Cette adresse email n'est pas valide."
        } catch AuthFailure.wrongCode {
            error = "Code faux ou expiré. Vérifie-le ou demande un nouveau code."
        } catch AuthFailure.nicknameTaken {
            error = "Ce pseudo est déjà pris. Essaie-en un autre."
        } catch AuthFailure.tooManyRequests {
            error = "Trop de demandes. Réessaie dans quelques minutes."
        } catch AuthFailure.offline {
            error = "Pas de connexion. Réessaie quand tu as du réseau."
        } catch {
            self.error = "Ça n'a pas marché. Réessaie."
        }
        return false
    }
}
