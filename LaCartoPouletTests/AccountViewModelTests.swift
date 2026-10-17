import Testing
@testable import LaCartoPoulet

final class FakeAuthService: AuthService, @unchecked Sendable {
    var signedInEmail: String?
    var savedNickname: String?
    var failure: AuthFailure?
    var sentTo: [String] = []

    func sendCode(to email: String) async throws {
        if let failure { throw failure }
        sentTo.append(email)
    }
    func verify(email: String, code: String) async throws {
        if let failure { throw failure }
        signedInEmail = email
    }
    func nickname() async throws -> String? { savedNickname }
    func setNickname(_ nickname: String) async throws {
        if let failure { throw failure }
        savedNickname = nickname
    }
    func signOut() async throws { signedInEmail = nil }
}

@MainActor struct AccountViewModelTests {
    @Test func firstSignInAsksForANickname() async {
        let auth = FakeAuthService()
        let model = AccountViewModel(auth: auth)
        model.email = " poule@example.com "
        await model.sendCode()
        #expect(model.step == .code)
        #expect(auth.sentTo == ["poule@example.com"])
        model.code = "123456"
        await model.verify()
        #expect(model.step == .nickname)
        model.nickname = "Poulette"
        await model.saveNickname()
        #expect(model.step == .signedIn)
        #expect(auth.savedNickname == "Poulette")
    }

    @Test func returningUserSkipsTheNickname() async {
        let auth = FakeAuthService()
        auth.savedNickname = "Crête-de-Feu"
        let model = AccountViewModel(auth: auth)
        model.email = "crete@example.com"
        await model.sendCode()
        model.code = "123456"
        await model.verify()
        #expect(model.step == .signedIn)
        #expect(model.nickname == "Crête-de-Feu")
    }

    @Test func invalidEmailIsCaughtBeforeSending() async {
        let auth = FakeAuthService()
        let model = AccountViewModel(auth: auth)
        model.email = "poule@"
        await model.sendCode()
        #expect(model.step == .email)
        #expect(model.error == "Cette adresse email n'est pas valide.")
        #expect(auth.sentTo.isEmpty)
    }

    @Test func wrongCodeStaysOnTheCode() async {
        let auth = FakeAuthService()
        let model = AccountViewModel(auth: auth)
        model.email = "poule@example.com"
        await model.sendCode()
        auth.failure = .wrongCode
        await model.verify()
        #expect(model.step == .code)
        #expect(model.error == "Code faux ou expiré. Vérifie-le ou demande un nouveau code.")
    }

    @Test func takenOrTooShortNickname() async {
        let auth = FakeAuthService()
        auth.signedInEmail = "poule@example.com"
        let model = AccountViewModel(auth: auth)
        await model.restore()
        #expect(model.step == .nickname)
        model.nickname = "Po"
        await model.saveNickname()
        #expect(model.error == "Ton pseudo doit faire entre 3 et 20 caractères.")
        auth.failure = .nicknameTaken
        model.nickname = "Poulette"
        await model.saveNickname()
        #expect(model.step == .nickname)
        #expect(model.error == "Ce pseudo est déjà pris. Essaie-en un autre.")
    }

    @Test func sessionSurvivesRelaunchAndSignOut() async {
        let auth = FakeAuthService()
        auth.signedInEmail = "crete@example.com"
        auth.savedNickname = "Crête-de-Feu"
        let model = AccountViewModel(auth: auth)
        await model.restore()
        #expect(model.isSignedIn && model.nickname == "Crête-de-Feu")
        await model.signOut()
        #expect(model.step == .email && auth.signedInEmail == nil)
    }
}
