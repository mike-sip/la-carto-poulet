import Foundation
import Supabase

struct BlockedUser: Decodable, Identifiable, Equatable {
    let id: UUID
    let nickname: String

    enum CodingKeys: String, CodingKey {
        case id = "blocked_id", nickname
    }
}

enum AuthFailure: Error, Equatable {
    case invalidEmail, wrongCode, nicknameTaken, tooManyRequests, offline
}

protocol AuthService: Sendable {
    /// The email of the session kept in the Keychain, so sign-in survives relaunches.
    var signedInEmail: String? { get }
    func sendCode(to email: String) async throws
    func verify(email: String, code: String) async throws
    /// My nickname, nil until I pick one.
    func nickname() async throws -> String?
    func setNickname(_ nickname: String) async throws
    func signOut() async throws
    func blockedUsers() async throws -> [BlockedUser]
    func block(_ userID: UUID) async throws
    func unblock(_ userID: UUID) async throws
}

struct SupabaseAuthService: AuthService {
    var signedInEmail: String? { supabase.auth.currentUser?.email }

    func sendCode(to email: String) async throws {
        try await mapped { try await supabase.auth.signInWithOTP(email: email) }
    }

    func verify(email: String, code: String) async throws {
        try await mapped { try await supabase.auth.verifyOTP(email: email, token: code, type: .email) }
    }

    func nickname() async throws -> String? {
        struct Profile: Decodable { let nickname: String }
        return try await mapped {
            let userID = try await supabase.auth.session.user.id
            let profiles: [Profile] = try await supabase.from("profiles").select("nickname")
                .eq("user_id", value: userID).execute().value
            return profiles.first?.nickname
        }
    }

    func setNickname(_ nickname: String) async throws {
        try await mapped {
            let userID = try await supabase.auth.session.user.id
            try await supabase.from("profiles")
                .upsert(["user_id": userID.uuidString, "nickname": nickname], onConflict: "user_id")
                .execute()
        }
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func blockedUsers() async throws -> [BlockedUser] {
        try await mapped {
            try await supabase.from("my_blocks").select("blocked_id, nickname")
                .order("created_at", ascending: false).execute().value
        }
    }

    func block(_ userID: UUID) async throws {
        try await mapped {
            let me = try await supabase.auth.session.user.id
            do {
                try await supabase.from("blocks")
                    .insert(["blocker_id": me.uuidString, "blocked_id": userID.uuidString]).execute()
            } catch let error as PostgrestError where error.code == "23505" {}  // already blocked
        }
    }

    func unblock(_ userID: UUID) async throws {
        try await mapped {
            try await supabase.from("blocks").delete().eq("blocked_id", value: userID).execute()
        }
    }

    /// Turns Supabase and network errors into the few cases the screens explain.
    private func mapped<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as AuthError {
            switch error.errorCode {
            case .otpExpired, .invalidCredentials: throw AuthFailure.wrongCode
            case .validationFailed, ErrorCode("email_address_invalid"): throw AuthFailure.invalidEmail
            case .overEmailSendRateLimit, .overRequestRateLimit: throw AuthFailure.tooManyRequests
            default: throw error
            }
        } catch let error as PostgrestError where error.code == "23505" {
            throw AuthFailure.nicknameTaken
        } catch is URLError {
            throw AuthFailure.offline
        }
    }
}
