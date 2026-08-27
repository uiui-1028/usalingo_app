import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// アプリの版と、問い合わせメールの組み立てをまとめる。
///
/// 画面から `Bundle` や `UIDevice` を直接読まないための1か所。読む場所が散らばると、
/// 表示の書式を変えるたびに複数の View を直すことになる。
enum AppInfo {
    /// 問い合わせ先。公開文書の窓口と同じ値にする。
    ///
    /// `docs/legal/published/` の窓口を変えたら、ここも変える。
    static let supportEmail = "support@usalingo.jp"

    /// 問い合わせメールに書き込む実行環境。
    ///
    /// 値を引数で渡せるようにしてあるのは、テストで固定値を使うため。
    struct Environment: Equatable {
        var shortVersion: String
        var buildNumber: String
        var systemName: String
        var systemVersion: String
        var deviceModel: String
    }

    /// 値を読めないときの表示。空文字にすると行が詰まって読みにくいため、明示する。
    static let unknownValue = "不明"

    static var current: Environment {
        Environment(
            shortVersion: infoDictionaryString("CFBundleShortVersionString"),
            buildNumber: infoDictionaryString("CFBundleVersion"),
            systemName: deviceSystemName,
            systemVersion: deviceSystemVersion,
            deviceModel: deviceModel
        )
    }

    /// 画面最下部に出す版の表示。
    static func versionLabel(_ environment: Environment = current) -> String {
        "バージョン \(environment.shortVersion) (\(environment.buildNumber))"
    }

    /// 問い合わせメールの件名。
    static func contactSubject(_ environment: Environment = current) -> String {
        "Usalingo お問い合わせ（\(environment.shortVersion)）"
    }

    /// 問い合わせメールの本文。
    ///
    /// 版と機種をあらかじめ書いておくと、返信のたびに聞き直す往復が消える。
    /// 機種名は `iPhone16,1` のような型番であり、端末を一意に識別する値ではない。
    /// 送信前に本人が編集・削除できる。
    static func contactBody(_ environment: Environment = current) -> String {
        """
        お問い合わせ内容をこの行に書いてください。


        ------------------------------
        以下は返信のための情報です。消しても送信できます。
        アプリ版: \(environment.shortVersion) (\(environment.buildNumber))
        OS: \(environment.systemName) \(environment.systemVersion)
        機種: \(environment.deviceModel)
        ------------------------------
        """
    }

    /// 問い合わせ用の `mailto:` URL。
    ///
    /// 件名と本文の記号や改行はここで百分率エンコードする。手で組み立てると、
    /// 全角文字や改行が入った時点で URL が壊れる。
    static func contactMailURL(
        _ environment: Environment = current,
        email: String = supportEmail
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: contactSubject(environment)),
            URLQueryItem(name: "body", value: contactBody(environment))
        ]
        return components.url
    }

    private static func infoDictionaryString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return unknownValue
        }
        return value
    }

    private static var deviceSystemName: String {
        #if canImport(UIKit)
        UIDevice.current.systemName
        #else
        "iOS"
        #endif
    }

    private static var deviceSystemVersion: String {
        #if canImport(UIKit)
        UIDevice.current.systemVersion
        #else
        unknownValue
        #endif
    }

    /// `iPhone16,1` のような型番を返す。`UIDevice.model` は "iPhone" としか返さず、
    /// 不具合の切り分けに使えないため、`uname` から読む。
    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let value = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: MemoryLayout.size(ofValue: pointer.pointee)
            ) { String(cString: $0) }
        }
        return value.isEmpty ? unknownValue : value
    }
}
