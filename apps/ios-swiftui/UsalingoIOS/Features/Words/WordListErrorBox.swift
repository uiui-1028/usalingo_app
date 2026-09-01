import SwiftUI

struct WordListErrorInfo {
    let number: String
    let action: String

    init(rawMessage: String) {
        let parsedCode = Self.databaseCode(from: rawMessage)
        number = parsedCode ?? Self.fallbackNumber(for: rawMessage)
        action = Self.recoveryAction(for: rawMessage, parsedCode: parsedCode)
    }

    private static func databaseCode(from rawMessage: String) -> String? {
        guard let data = rawMessage.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? String,
              !code.isEmpty else {
            return nil
        }
        return code
    }

    private static func fallbackNumber(for rawMessage: String) -> String {
        let lowercased = rawMessage.lowercased()
        if lowercased.contains("timed out") || lowercased.contains("offline") || lowercased.contains("network") {
            return "WL-001"
        }
        if lowercased.contains("unauthorized") || lowercased.contains("jwt") || lowercased.contains("session") {
            return "WL-002"
        }
        return "WL-000"
    }

    private static func recoveryAction(for rawMessage: String, parsedCode: String?) -> String {
        let lowercased = rawMessage.lowercased()
        if lowercased.contains("relation") || parsedCode == "42P01" {
            return "データベースの単語テーブル設定を確認してください。"
        }
        if lowercased.contains("permission") || lowercased.contains("rls") || parsedCode == "42501" {
            return "ログイン状態またはデータベース権限を確認してください。"
        }
        if lowercased.contains("unauthorized") || lowercased.contains("jwt") || lowercased.contains("session") {
            return "一度サインアウトしてから、再度サインインしてください。"
        }
        if lowercased.contains("timed out") || lowercased.contains("offline") || lowercased.contains("network") {
            return "通信状態を確認してから、もう一度読み込んでください。"
        }
        return "時間をおいて再読み込みしてください。改善しない場合はエラー番号を控えてください。"
    }
}

struct WordListErrorBox: View {
    let info: WordListErrorInfo
    let retry: () -> Void

    var body: some View {
        // 色相を使わずに異常を示す（破線 + 文言）。
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            HStack(spacing: WireMetrics.spacingM) {
                Image(systemName: "exclamationmark.triangle")
                    .wireFont(.titleS)
                    .frame(width: 42, height: 42)
                    .outlineCircleSurface()

                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text("読み込みできません")
                        .wireFont(.titleS)
                    Text("エラー番号: \(info.number)")
                        .wireFont(.caption)
                }
            }

            Text("対処方法: \(info.action)")
                .wireFont(.body)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                retry()
            } label: {
                Label("再読み込み", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.wireSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card, dashed: true)
    }
}
