import Foundation

/// 利用者が打ったメールアドレスを、送る前に整える。
///
/// 貼り付けで付いた前後の空白、日本語入力のままの全角文字、大文字のような
/// 「意味は明らかな打ち方の違い」は黙って直す。途中の空白やドメインの
/// 打ち間違いのように、直し方を決めつけられないものは直さずに知らせる。
/// パスワードは空白も中身の一部なので、ここでは扱わない。
enum EmailInput {
    /// 意味を変えずに直せる違いだけをそろえる。
    static func normalized(_ raw: String) -> String {
        // NFKC で全角英数字・全角記号・全角スペースを半角へ寄せる。
        raw.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// 整えたうえで、送ってもよい形かを確かめる。
    static func validated(_ raw: String) throws -> String {
        let email = normalized(raw)
        guard !email.isEmpty else { throw AuthError.emailRequired }
        guard email.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw AuthError.emailContainsSpace
        }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].contains("."),
              !parts[1].hasPrefix("."),
              !parts[1].hasSuffix("."),
              !parts[1].contains("..") else {
            throw AuthError.emailInvalidFormat
        }
        return email
    }

    /// よく使われるドメインの打ち間違いらしければ、直した候補を返す。勝手には直さない。
    static func suggestion(for raw: String) -> String? {
        let email = normalized(raw)
        guard let at = email.lastIndex(of: "@") else { return nil }
        let domain = String(email[email.index(after: at)...])
        guard !domain.isEmpty, !commonDomains.contains(domain) else { return nil }

        // 短いドメイン同士（me.com と au.com など）は2文字違いでも別物なので、1文字までにする。
        let allowed = domain.count >= 9 ? 2 : 1
        let best = commonDomains
            .map { ($0, editDistance(domain, $0)) }
            .filter { $0.1 <= allowed }
            .min { ($0.1, $0.0) < ($1.1, $1.0) }
        return best.map { email[..<at] + "@" + $0.0 }
    }

    private static let commonDomains: Set<String> = [
        "gmail.com", "googlemail.com", "mail.com", "email.com", "ymail.com",
        "yahoo.co.jp", "yahoo.com", "ymail.ne.jp",
        "icloud.com", "me.com", "mac.com", "outlook.com", "outlook.jp",
        "hotmail.com", "hotmail.co.jp", "live.jp",
        "docomo.ne.jp", "ezweb.ne.jp", "au.com", "softbank.ne.jp", "i.softbank.jp"
    ]

    /// 2つの文字列が何文字の追加・削除・置換で一致するか。どちらも空でない前提。
    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                )
            }
            previous = current
        }
        return previous[b.count]
    }
}
