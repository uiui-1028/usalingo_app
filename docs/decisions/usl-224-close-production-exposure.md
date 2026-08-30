# USL-224 本番だけに存在したオブジェクトの公開を閉じる

- 判定: **実装済み・ローカル検証済み。本番未適用**
- 日付: 2026-08-30
- 対象migration: `supabase/migrations/20260830150000_close_production_only_exposure.sql`
- 対象テスト: `supabase/tests/usl_224_production_exposure_closed.test.sql`
- 実行境界: ローカルの使い捨てPostgreSQLのみ。本番Supabaseへの接続・DDL・DML・Storage変更は0件。

## 背景

[USL-270](usl-270-production-only-objects.md) の
`20260830090000_record_production_only_objects.sql` は、本番にSQL Editorから直接作られ
migrationに記録されていなかったオブジェクトを、**そのまま**写し取った現状記録である。
改善ではないため、既知の危険をあえて再現していた。

[USL-244](usl-244-production-stop-audit.md) の本番読み取り監査は、その危険を理由に
「停止」と判定し、解除条件1〜3を挙げた。この課題はその3件を1つのmigrationで閉じる。

なお、監査当時に4件目として挙がっていた `public.sync_existing_images` は
[USL-276](usl-276-drop-sync-existing-images.md) で削除済みである。

## 何を閉じたか

| 解除条件 | 対象 | 変更 |
| --- | --- | --- |
| 1 | `setup_content_images_policies()`、`optimize_content_audio_policies()` | `public`・`anon`・`authenticated`・`service_role` から `EXECUTE` を取消。owner だけが実行できる |
| 1 | `get_index_recommendations()`、`get_performance_summary()` | クライアントroleから取消し、`service_role` だけに残す |
| 2 | `asset_processing_queue` | RLSを有効化。policyは作らない。クライアントroleのGRANTを全取消し、`service_role` だけに残す |
| 3 | 6つのview | `security_invoker = true`。公式コンテンツ2件は`SELECT`のみ残し、監視系4件はクライアントroleから全取消 |

いずれも定義側の `search_path` は元から `public` に固定されており、この課題では触っていない。

### 判断の根拠

- **なぜ取り消して壊れないか**: `apps/ios-swiftui/` のSwiftコードと Edge Function
  `delete-user-account` を検索したが、ここで扱うtable・view・関数の呼び出しは0件だった。
- **なぜ関数を削除ではなく取消にしたか**: 2つのStorage policy関数は、内容自体は
  現行スキーマで動く。運用で必要になる可能性が残るため、公開だけを閉じて定義は残した。
  壊れて復元の見込みがない `sync_existing_images` だけがUSL-276で削除対象になった。
- **なぜqueueにpolicyを作らないか**: policyが無いRLS有効tableは、RLSをbypassしない
  すべてのroleに対して0行になる。GRANT取消と合わせて二重に閉じる。`service_role` は
  RLSをbypassするため、サーバー側の処理は影響を受けない。
- **なぜviewの`GRANT ALL`が危険だったか**: 単純なviewは自動更新可能である。
  `v_word_meanings_with_paths` と `v_example_contents_with_paths` への
  `INSERT`・`UPDATE`・`DELETE` は、基底tableへの書込経路になりうる。

## 検証

migration自身が末尾の `do $$ ... $$` で、RLS・policy件数・関数権限・view権限・
`security_invoker` を確かめ、期待から外れていれば `raise exception` で失敗する。
`20260821133424_enforce_current_app_grants.sql` と同じ方針である。

加えて、pgTAP 26件を新規に追加し、将来の回帰で落ちるようにした。

`sh scripts/test-sql-without-docker.sh` の結果:

| 項目 | 結果 |
| --- | --- |
| migration | 15件すべて適用成功 |
| pgTAP | 80件中 0件失敗（うち本課題の新規26件） |
| lint | error 0件。終了コード0 |

[Dockerなしの検証手順](../operations/sql-verification-without-docker.md)に書かれているとおり、
この環境で確認できるのは「SQLが通り、カタログ上のオブジェクトが期待どおりの形になるか」まで
である。`auth.uid()` が常にNULLのため、RLSの**実際の遮断**は確認できていない。
ただし本課題の変更は、行の絞り込みではなくGRANTと`security_invoker`と
「policyが無いこと」であり、いずれもカタログで判定できる性質のものである。

## 残っていること

1. Dockerのある環境で `./scripts/test-local-db.sh` を回し、実際の遮断を確認する。
2. [USL-244](usl-244-production-stop-audit.md) を再監査する。本番を読み取りのみで再確認し、
   停止3条件が「合格」へ変わることと、Security Advisorの6件のERRORが消えることを見る。
3. USL-245の本番適用は、その後も人間の明示承認が必要である。
