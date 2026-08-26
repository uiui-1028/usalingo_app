import Foundation

enum SupabaseConfig {
    static let authCallbackURL = URL(string: "com.usalingo.ios://auth-callback")!
    private static let projectRef = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PROJECT_REF") as? String ?? ""

    static let supabaseURL = projectRef.isEmpty ? "" : "https://\(projectRef).supabase.co"
    static let supabaseAnonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""

    static var restURL: URL {
        URL(string: "\(supabaseURL)/rest/v1")!
    }

    static var authURL: URL {
        URL(string: "\(supabaseURL)/auth/v1")!
    }

    static var functionsURL: URL {
        URL(string: "\(supabaseURL)/functions/v1")!
    }

    static func publicStorageURL(for path: String) -> URL? {
        URL(string: "\(supabaseURL)/storage/v1/object/public/\(path)")
    }
}
