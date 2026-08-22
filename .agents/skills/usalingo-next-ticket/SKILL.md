---
name: usalingo-next-ticket
description: UsalingoのVer.2.0 Taskspaceから次の着手可能チケットを安全に取得し、専用ブランチで調査、実装、テスト、AIレビュー、Notion完了報告まで進める。CodexまたはCursorで「次のチケットを進めて」「Notionから取って作業して」「同じチケット作業を繰り返して」または /usalingo-next-ticket と依頼されたときに使う。
---

# Usalingo Next Ticket

1件のチケットを安全に取得し、AIレビュー合格または明確なblocked判定まで進める。

## 必ず従うもの

1. リポジトリの `AGENTS.md` と `docs/rules/codex-credit-optimization.md` を読む。
2. `../usalingo-project-manager/SKILL.md` を使い、Notion利用時は同スキルが指定する参照も読む。
3. Supabase、GitHub、文書など別スキルの対象へ入ったら、利用中のAIクライアントで該当スキルが使える場合はそれも使う。

## 取得条件

Ver.2.0 Taskspace `collection://7c0c3d1f-59e8-83f8-8958-07b0b1cf4a03` だけを使う。

- `status=will`
- `owner` が `human` ではない（空欄も含む）
- `blocked_by` がすべて `done`
- 他AIの有効な `lease_until` がない

`status=will` を着手許可として扱い、Priority、Issue IDの順で選ぶ。`owner=human` だけはAIが取得しない。`owner` が空欄でも取得対象に含める。SQLでは `owner IS NULL OR owner = '' OR owner != 'human'` として判定する。`reserve` は将来候補、`review` はレビュー工程なので、このスキル呼び出しだけで `will` へ変更しない。`owner=human`、`reserve`、`review`、有効期限内の他AI作業、未完了依存へ条件を広げない。`approval` は削除済みのため、照会・更新・本文確認の対象にしない。

## 最小照会フロー

1. `git status --short --branch` で既存差分を保護する。
2. Notion接続の `self` をfetchし、正しいワークスペースと `query_data_sources` の利用可否を確認する。
3. Taskspaceスキーマをfetchし、着手候補を1回の `query_data_sources` SQLで取得する。
4. 候補が0件なら何も変更せず、解除条件だけ報告する。
5. 先頭候補のページ本文をfetchし、受け入れ条件と危険操作を確認する。
6. クライアント名を小文字にした接頭辞を使い、チケットごとに `<client>/usl-<番号>-<短い名前>` の新規専用ブランチを作る。Cursorは `cursor/`、Codexは `codex/` を使う。既存ブランチを再利用せず、同名が存在する場合は一意な接尾辞を付ける。現在のworktreeに既存差分がある場合は、その差分を残したまま、新規ブランチ用の別worktreeを作る。
7. `<client>-<一意な文字列>` の `worker_id`、30分後のタイムゾーン付き `lease_until`、`work_branch`、`status=run` を1回で更新する。
8. 直後にページを再取得し、`worker_id`、`lease_until`、`work_branch` が自分の値であることを確認する。競合したら編集せず停止する。

`query_data_sources` は原則、着手前1回と完了後1回だけ使う。fetchと更新をSQL代わりに乱用せず、同じ情報を再取得しない。利用枠エラーが出たら同じ照会を繰り返さず、停止して解除条件を報告する。

## 実施と完了

1. チケットの対象だけを調査・変更する。現行アプリは `apps/ios-swiftui/` を基準にする。
2. 20分以内ごと、および重要な書き込み前に作業権を再確認・延長する。
3. 対象テストを実行し、必要なら関連テストまで広げる。
4. `run` から `review` へ移し、受け入れ条件、実差分、テスト、未確認事項を別工程としてAIレビューする。
5. 不備は修正して再検証する。合格時だけ完了レポートを追記し、`done`、終了日、空の `lease_until` を設定する。
6. 必須環境や権限がなく完了できなければ、解除条件を記録して `blocked` とし、作業権を返す。
7. 完了後の1回のSQLで、`status=will` かつ `owner` が `human` ではない（空欄を含む）次候補をまとめて取得し、上位2〜3件を報告する。

## 権限境界

- このスキル呼び出しだけでは、stage、commit、push、PR作成、公開、本番DB変更、データ削除、課金、外部送信を実行しない。
- 戻しにくい操作は直前に対象と危険を示し、明示承認を得る。
- ローカルの可逆な実装、テスト、Notionの作業権・進捗・完了報告は追加確認なしで進める。
- 実装済み、テスト済み、本番確認済みを分けて報告する。

## 呼び出し例

Cursorでは `/usalingo-next-ticket`、Codexでは `$usalingo-next-ticket` を使う。自然文の「次のチケットを進めて」でもよい。

追加条件がある場合だけ同じ行へ続ける。

`/usalingo-next-ticket 本番変更はせず、SwiftUIの課題を優先して`
