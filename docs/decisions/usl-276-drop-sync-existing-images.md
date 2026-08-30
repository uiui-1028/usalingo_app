# USL-276 壊れた sync_existing_images を直さず削除する

決定日: 2026-08-30

## 決めること

`public.sync_existing_images()` を、現行スキーマに合わせて直すか、削除するか。

## 選択肢

| | 内容 | 評価 |
| --- | --- | --- |
| A 直す | `meaning_id` 経由の結合へ書き換え、`illustration_url` を `image_asset_path` へ変える | 呼び出し元が無いものを推測で書き直すことになる。ファイル名から単語を取り出す前提が現在の命名規則と合うかも不明 |
| B 削除する | `DROP FUNCTION public.sync_existing_images()` | 後継が既にあり、露出面も減る |

## 決めたこと

**B。削除する。**

## 理由

1. **スキーマが変わった時点から壊れており、正常に動いていた呼び出し元は存在しえない。**
   `example_contents` に `word_id` も `illustration_url` も無い。呼べば必ず 42703 で失敗する。
   多義語対応で `word_id` 直参照が `meaning_id` 経由へ、画像の持ち方が URL 文字列からパスへ変わったとき、
   この関数だけが取り残された。plpgsql は本体を実行時にしか検証しないため、
   壊れていることが今日まで表に出なかった。

2. **同じ仕事は既に後継が現行スキーマで行っている。**
   本番の Edge Function `asset-linker-v4-corrected`（version 2、2026-10-05 更新）は、
   ID からファイル名（`image_example_<id>.webp` / `audio_example_<id>.mp3`）を生成し、
   Storage で存在を確かめて `illustration_asset_path` / `audio_asset_path` を書く。
   `sync_existing_images` がやろうとしていたこと（ファイル名から対象行を見つけて画像パスを書く）を、
   ファイル名の推測ではなく ID から決定的に導く形へ作り直したものである。
   この Edge Function は `sync_existing_images` を呼んでいない。

3. **アプリは呼んでいない。**
   `apps/ios-swiftui/` の REST 経路は `words`、`cards`、`user_card_progress`、`user_profiles`、
   `user_word_tags`、`user_word_overrides`、`rpc/ensure_current_user_row` だけである。

4. **消せば露出面が減る。**
   `anon` から実行できる `SECURITY DEFINER` 関数であり、`anon` キーはアプリに配布される。
   壊れたまま残す利点が無い。

## 影響する場所

- `supabase/migrations/20260830120000_drop_broken_sync_existing_images.sql`（この決定の実行）
- `supabase/migrations/20260830090000_record_production_only_objects.sql` 第3節（定義の記録。残す）
- `docs/decisions/usl-270-production-only-objects.md`（同じ危険を「未確認のこと」として記載済み）

## 確認したこと

| 確認 | 方法 | 結果 |
| --- | --- | --- |
| Edge Function から呼ばれていない | 本番 `asset-linker-v4-corrected` の全文を読み取りで確認 | 呼び出しなし。後継として同じ役割を果たしている |
| アプリから呼ばれていない | `apps/ios-swiftui/` の REST 経路を全数確認 | 呼び出しなし |
| migration が通る | `sh scripts/test-sql-without-docker.sh` | 14/14 適用成功 |
| lint が通る | 同上（`supabase db lint --fail-on error`） | **error 0件**（削除前は1件） |
| pgTAP が壊れない | 同上 | 54件中 0件失敗 |

## 未確認のこと

- **本番への適用は行っていない。** この決定はリポジトリ上の migration までである。
  本番の `public.sync_existing_images()` は今も存在する。適用は承認を得た別課題で行う。
- 本番の残り6つの Edge Function（`asset-linker` v1〜v3、`migrate-assets`、`asset-queue-processor`）の
  中身は読んでいない。いずれも `asset-linker-v4-corrected` より古い同系統か、
  リポジトリに実体の無い運用ツールであり、仮にこの関数を呼んでいたとしても、
  スキーマ変更以降ずっと失敗している。理由1がその場合も成り立つ。

## 見直す条件

ファイル名から対象行を見つける一括同期が再び必要になった場合。
そのときは `asset-linker-v4-corrected` の方式（ID からファイル名を導く）を出発点にする。
削除した定義は `20260830090000_record_production_only_objects.sql` と git 履歴に残っている。
