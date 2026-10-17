import Foundation
import Supabase

/// URL and anon key come from the git-ignored Config.xcconfig through Info.plist.
let supabase: SupabaseClient = {
    let info = Bundle.main.infoDictionary ?? [:]
    guard let urlString = info["SupabaseURL"] as? String, let url = URL(string: urlString),
          let key = info["SupabaseAnonKey"] as? String, !key.isEmpty else {
        fatalError("Missing SUPABASE_URL / SUPABASE_ANON_KEY: copy Config.xcconfig.example to Config.xcconfig")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: key)
}()
