# USL-243 Anki migration ローカル検証

確認日: 2026-08-23

## 結論

本番から隔離したローカル Supabase で、Anki migration と公式コンテンツ契約 migration の適用、合成進捗のコピー、RLS・GRANT・Storage、制約、切り戻しを確認した。対象 migration SQL と SwiftUI コードは変更していない。

## 実行境界

- 実行環境: `codex/usl-222-local-supabase` の未コミットローカル検証環境
- 結果文書: `codex/usl-243-anki-dev-db-2`
- Supabase CLI: 2.33.9
- Docker: 29.7.2
- 接続先: API、DB、Studio、Mailpit はすべて `127.0.0.1`
- 本番 Supabase: 接続・読み取り・書き込みを一度も行っていない
- データ: `example.test` の合成利用者2件と合成学習データだけを使用

`main` だけでは baseline migration がなく、全 migration は2本目で停止する。USL-222 の作業場所にある次の未コミットファイルを前提として検証した。

- `supabase/migrations/20260411000000_create_current_baseline_schema.sql`
- `supabase/migrations/20260821133424_enforce_current_app_grants.sql`
- `supabase/config.toml`
- `supabase/seed.sql`
- `supabase/tests/usl_222_local_environment.test.sql`

## migration とデータコピー

1. `supabase db reset --local --version 20260627000100 --no-seed` で Anki migration 直前を再現した。
2. 合成利用者2件、単語1件、Deck 2件、`deck_words` 2件、旧進捗1件を作った。
3. `supabase migration up --local` で Anki migration、公式コンテンツ契約、GRANT migration を適用した。
4. Card は期待2件・実2件、旧進捗1件から Card進捗は期待2件・実2件だった。
5. `status`、SRS level、repetitions、incorrect count、interval days は2件とも旧進捗と一致した。
6. migration 内の最終 gate が、件数、移行漏れ、コピー列、権限、RLS policy を検査して成功した。

## Data API・RLS・Storage

- 利用者A: 自分の Card進捗2件を読み取れた。
- 利用者B: Aの進捗は0件。Aへの更新も0件で、Aの値は変わらなかった。
- 匿名: Card読取は401。
- 認証利用者: 公式Card更新は403。
- 認証利用者: `content-images` への書込は400で拒否。
- CHECK制約: `incorrect_count=-1` は400で拒否。
- 旧 `user_learning_progress` は残り、移行後も1件を読み取れた。
- pgTAP 34件すべて成功。全アプリ表のRLS、Data API GRANT、Storage bucket 2件、MIME制限、asset path制約を確認した。
- `supabase db lint --local --schema public --fail-on error`: schema error 0件。

## 切り戻し

`supabase db reset --local --version 20260627000100 --no-seed` で環境を再作成した。

- 旧 `user_learning_progress`: 存在
- 新 `cards`: 存在しない
- 新 `user_card_progress`: 存在しない

その後、`supabase db reset --local` を再実行し、全 migration、seed、pgTAP 34件、lint を成功させて標準ローカル状態へ戻した。

## 残る注意

この検証をほかの人が `main` から再現するには、USL-222 の未コミット baseline、config、seed、tests を先に統合する必要がある。このチケットでは commit、push、本番適用を行っていない。
