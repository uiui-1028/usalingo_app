# USL-248 現行認証と Supabase Auth 設定の差分調査

確認日: 2026-08-23

この文書は、ローカルコードと本番 Supabase Dashboard を読み取った調査結果である。Auth 設定、利用者、データは変更していない。秘密情報や個人情報は記録していない。

## 結論

現在の SwiftUI アプリは、メールアドレスとパスワードで登録・ログインし、セッションを Keychain に保存して次回起動時に更新する。パスワード再設定、メールアドレス変更、再認証、退会、メールリンクを受けるディープリンクは未実装である。

本番ではメール確認と安全なメール変更が有効である。一方、Site URL と Redirect URL は localhost のみで、iOS の callback URL はない。内蔵メール送信は本番用途向けではないという Dashboard の警告があり、custom SMTP は未設定である。

## 現在の経路（ローカルコード確認済み）

```text
登録: AuthView → POST /auth/v1/signup → ensure_current_user_row → Keychain → AppState
ログイン: AuthView → POST /auth/v1/token?grant_type=password → ensure_current_user_row → Keychain → AppState
起動時: AppState → Keychain → POST /auth/v1/token?grant_type=refresh_token → Keychain を更新
サインアウト: AppState → Keychain のセッション削除 → AppState を空にする
```

`AuthService` はアクセストークン、リフレッシュトークン、期限、利用者 ID を保存する。サインアウトは端末内のセッションだけを削除し、Supabase Auth のサーバー側セッションは無効化しない。

## 差分表

| 項目 | ローカルコード | 本番設定（読み取り確認） | 後続実装に必要なもの |
| --- | --- | --- | --- |
| 新規登録 | Email/password の `signup` を実装 | 新規登録 ON、Email provider ON、メール確認 ON、匿名登録 OFF | 登録直後は「確認メールを開いてからログイン」と明示する |
| ログイン | password grant を実装 | CAPTCHA OFF、漏えいパスワード検査 OFF | エラー表示、必要なら CAPTCHA と保護方針を決める |
| セッション | refresh token で起動時更新 | access token 3600秒、refresh token 不正利用検知 ON、再利用間隔10秒、時間・非活動期限なし | 期限切れ時の再ログインとサーバー側ログアウトを実装する |
| パスワード | 入力欄だけ。変更・回復は未実装 | 最小長は既定値のまま、追加文字要件なし、安全なパスワード変更 OFF、現在パスワード要求 OFF | `resetPasswordForEmail` 相当、callback 受信、`updateUser` 相当を追加する |
| メール変更 | 未実装 | 新旧両方への確認を求める安全なメール変更 ON | `updateUser` 相当、確認待ち・完了画面を追加する |
| 再認証 | 未実装 | 再認証用メールテンプレートあり。安全なパスワード変更 OFF | 重要操作前の再認証方法と有効時間を設計する |
| ディープリンク | URL scheme、`onOpenURL` と callback 処理なし | Site URL は `http://localhost:3000`。Redirect URL は `/auth/callback` と `/auth/update-password` の localhost 2件だけ | iOS callback URL を登録し、受信 URL から安全にセッションを確立する |
| 退会 | 未実装 | Dashboard からはアプリ固有の削除処理を確認できない | 再認証後、サーバー側の管理処理で Auth user と関連データを削除する |
| メール送信 | 未実装 | 内蔵メール送信を使用。custom SMTP 未設定 | 本番用 SMTP、送信元、到達性、失敗時案内を設定・検証する |

## 本番 Auth 設定（2026-08-23、読み取り確認済み）

- Email provider: ON。メール確認: ON。新規登録: ON。匿名登録: OFF。manual linking: OFF。
- Secure email change: ON。Secure password change: OFF。現在パスワード要求: OFF。漏えいパスワード検査: OFF。
- Password minimum length は Dashboard の入力が空欄（既定値）。追加の文字種要件は未選択。
- Email OTP: 有効期限 3600秒、6桁。
- Site URL: `http://localhost:3000`。
- Redirect URL: `http://localhost:3000/auth/callback`、`http://localhost:3000/auth/update-password`。iOS 用 custom scheme は0件。
- Session: access token 3600秒、refresh token 不正利用検知 ON、refresh reuse interval 10秒。single session は Free plan では利用不可。time-box と inactivity timeout は無期限。
- Attack protection: CAPTCHA OFF、漏えいパスワード検査 OFF。
- メール送信: Supabase 内蔵サービス。Dashboard に本番用途向けではない旨の警告あり。custom SMTP 未設定。
- レート制限: token refresh 150回/5分、token verification 30回/5分、signup/signin 30回/5分。匿名 30回/時と Web3 30回/5分は画面上無効。メール送信欄は内蔵サービス管理のため値を確認できない。

## 後続実装に必要な API とディープリンク

1. iOS 固有の callback URL を決め、`CFBundleURLTypes` と Supabase の Additional Redirect URLs に同じ値を登録する。
2. SwiftUI の `onOpenURL` などで callback を受け、エラーと認証状態を検証してセッションを反映する。
3. パスワード再設定は回復メール送信（`resetPasswordForEmail`／`/auth/v1/recover` 相当）と、callback 後のパスワード更新（`updateUser`／`/auth/v1/user` 相当）を実装する。
4. メール変更は `updateUser` 相当を使い、新旧メールの確認待ちと完了を区別する。
5. 重要操作では再認証（`reauthenticate`／`/auth/v1/reauthenticate` 相当）を行う。退会は service role をアプリに置かず、認可されたサーバー処理から実行する。

公式ガイド上、ネイティブアプリのメール確認、パスワード回復、magic link などには、許可済み Redirect URL とアプリ側のリンク受信処理が必要である。

## 検証境界

- ローカルコード: 対象 Swift、Info.plist、Xcode project を静的に確認した。
- 本番: Dashboard の Auth 設定を読み取り確認した。設定変更・利用者操作はしていない。
- 未確認: 実際のメール到達性、callback の実機動作、アカウント変更・削除の実動作。これらは未実装のため確認していない。
- このチケットでコード実装、Docker、migration、デプロイは行っていない。
