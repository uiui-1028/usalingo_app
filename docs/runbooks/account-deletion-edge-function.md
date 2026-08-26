# アカウント退会Edge Function運用手順

対象: `delete-user-account`。本番デプロイや実利用者への実行は、この文書を追加承認の代わりにしない。

## 処理境界

- 利用者JWTから本人を確定し、本文の `user_id` は対象決定に使わない。
- パスワード再入力と「退会」の確認後、退会状態を先に保存する。
- Authユーザーは退会当日に削除せず、復元処理だけが解除する長期banを設定し、全refresh tokenを失効させる。期限後のpurge jobが遅れてもログインを再開しない。
- restrictive RLSで既発行access tokenから利用者データを読書きできないようにする。
- 同じrequest IDは同じ状態を返し、完了済みstepを繰り返さない。
- 365日後は、server secretだけが呼べる `operation=purge` が期限をDBで再確認し、利用者所有Storageが0件の場合だけAuthユーザーを物理削除する。外部キーcascade後は個人に結び付く監査行も残さない。
- 復元処理と自動jobは本番監査後の後続実装とする。

## ローカル確認

```sh
supabase start
supabase db reset --local
supabase test db --local
deno test supabase/functions/delete-user-account/core_test.ts
```

`supabase functions serve delete-user-account` を使う統合確認では、利用者A/Bを作り、匿名・誤パスワード・異なる本文user_idを拒否すること、Aの退会後もBと公式コンテンツが残ること、同じrequest IDの再送が期限を延ばさないことを確認する。ログへAuthorization、パスワード、service role、レスポンス本文を出してはいけない。

## 本番前の停止条件

- 本番DBの全外部キー、`user_id`列、Storage owner、外部サービス、バックアップ保持期間の読取監査が未完了
- Authのban解除による同一ID復元を隔離環境で確認していない
- 既発行JWTの有効時間と、機密経路の退会状態チェックが合意されていない
- service role secret、監視、再試行job、運用担当、法務・プライバシー担当が未設定
- プライバシーポリシー、App Store Connect、アプリ表示が365日契約と一致していない

## 切り戻し・復旧

本番投入前はmigrationとFunctionをデプロイしない。投入後に受付処理が失敗した場合、退会状態を勝手に削除したりAuthを再開したりせず、`failed_step` と秘密を含まない `failure_code` を確認して未完了stepを再実行する。ban後の失敗はログイン停止を維持する。最終削除開始後は個人データを復元せず、安全な削除完了へ進める。
