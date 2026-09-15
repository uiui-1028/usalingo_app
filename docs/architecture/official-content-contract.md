# 公式コンテンツのDB・Storage契約

最終更新日: 2026-09-07  
対象: SwiftUIアプリ `apps/ios-swiftui/` とSupabase  
状態: ローカル設計・migration作成済み。本番Supabaseには未適用

## 1. 目的

別ルートで作る単語、例文、画像、音声を、運営とアプリが同じ規則で受け渡せるようにします。この文書は公式コンテンツの列、Storageパス、欠損時動作、アクセス権の正本です。

コンテンツ制作、ファイルの本番アップロード、既存データの内容監査は含めません。

## 2. DBの受け渡し項目

SwiftUIが1枚の表示用データを作るための最低条件です。

| テーブル | 項目 | 必須 | 用途・欠損時 |
|---|---|---:|---|
| `words` | `id` | 必須 | Noteの安定ID |
| `words` | `word_text` | 必須 | 英単語。欠損行は表示できない |
| `word_meanings` | `id`, `word_id` | 必須 | 単語と意味の接続 |
| `word_meanings` | `priority` | 必須 | 小さい値を優先する |
| `word_meanings` | `definition_jp` | 必須 | 日本語の答え。欠損行は表示できない |
| `word_meanings` | `part_of_speech_en` | 任意 | 欠損時は品詞を表示しない |
| `example_contents` | `id`, `meaning_id` | 必須 | 例文とメディアの接続 |
| `example_contents` | `sentence_en`, `sentence_jp` | 任意 | 欠損した側を表示しない |
| `example_contents` | `image_asset_path` | 任意 | 欠損時は画像の代替表示を使う |
| `example_contents` | `audio_asset_path` | 任意 | 欠損時は再生操作を無効にする |

少なくとも `word_text` と最優先の `definition_jp` がない行は学習Cardに変換しません。画像や音声がないことはデータエラーではありません。空文字は使わず、ない値は `NULL` にします。

## 3. Storageパス

DBには完全URLではなく、`bucket/object-key` を保存します。`theme-slug` は半角小文字、数字、ハイフンだけを使い、表示名の `シンプル` とは分けます。

| 種類 | DB列 | 規則 | 例 |
|---|---|---|---|
| 例文画像 | `image_asset_path` | `content-images/<theme-slug>/<shelf>/example-<id6>.webp` | `content-images/simple/000/example-000100.webp` |
| 例文音声 | `audio_asset_path` | `content-audio/example/<theme-slug>/<shelf>/example-<id6>.mp3` | `content-audio/example/simple/000/example-000100.mp3` |
| 単語音声 | `word_pronunciations.audio_asset_path` | `content-audio/word/<shelf>/pron-<id6>.mp3` | `content-audio/word/000/pron-000100.mp3` |

`id6` はIDを6けたにそろえた数字です（`100` → `000100`）。`shelf` は `id6` の頭3けたです。

- ID 1〜999: `000`
- ID 1000〜1999: `001`
- ID 2000〜2999: `002`

`id6` は `example_contents.id`（単語音声は `word_pronunciations.id`）と一致させます。原本シートの `example_id`・`pronunciation_id` も同じ整数です。
同じパスへ別の中身を上書きしません。公開ファイルは `max-age=3600` で配り、アプリも画像をURLごとに端末へ保存するため、上書きすると古い中身が出続けます。
経緯は [画像と音声のファイル名に種類と6けたの番号を付ける](../decisions/content-file-naming-padded-with-kind-20260915.md) にあります。
音声のパスは原本シートに書かず、取りこみがIDから作ります。Storageにファイルがあるときだけ値を入れます。画像はWebP、音声はMP3だけをこの契約の対象にします。SwiftUIは相対パスを `SupabaseConfig.publicStorageURL(for:)` で公開URLへ変換します。

## 4. 読み取りと書き込み

| 対象 | 未認証利用者 | 認証利用者 | 運営の信頼済み処理 |
|---|---|---|---|
| 公式DB (`words` など) | 不可 | 読み取りのみ | `service_role` で書き込み |
| 個人デッキ (`decks.owner_id = 本人`, その配下の `cards`) | 不可 | 本人の行だけ読み書き | 必要時だけ管理 |
| 公開画像・音声 | URLを知れば読み取り可 | 読み取り可 | `service_role` でアップロード・更新・削除 |
| 利用者の学習記録 | 不可 | 本人の行だけ読み書き | 必要時だけ管理 |

公開bucketはファイル取得だけを公開します。アップロード、上書き、移動、削除を許可する `anon` / `authenticated` 用Storage policyは作りません。運営処理はiOSアプリ外の信頼済み環境で行い、`service_role` をアプリへ入れません。

DBのGRANTとRLSは別の門です。公式DBは `authenticated` へ `SELECT` だけをGRANTし、RLSでも読み取りだけを許可します。

例外は `decks` と `cards` の**個人デッキ**です。2026-09-07 の
[決定](../decisions/user-owned-decks-scope-20260907.md) により、この2表だけは
`authenticated` へ `INSERT` / `UPDATE` / `DELETE` もGRANTします。ただしRLSで
`decks.owner_id = auth.uid()` の行に限定し、公式行（`owner_id IS NULL`）への
書き込みは一切許可しません。「公式コンテンツは読み取り専用」はこの例外でも保たれます。

具体的な公式DB権限は各テーブルのmigrationを正本とし、本番適用前に現在のpolicyとGRANTを再監査します。

## 5. 欠損・不正値の扱い

- `image_asset_path IS NULL`: カードを残し、画像の代替表示を使う。
- `audio_asset_path IS NULL`: カードを残し、再生ボタンを無効にする。
- パスはあるが取得に失敗: 画面全体を失敗させず、画像は代替表示、音声は再生失敗として扱う。
- パス形式またはIDが規則外: 新しいmigrationのCHECK制約で拒否する。
- 必須文字列が欠損: 運営データの不備として修正し、代替文を自動生成しない。

## 6. 実装と適用の境界

実行可能SQLは [`20260812055432_define_official_content_contract.sql`](../../supabase/migrations/20260812055432_define_official_content_contract.sql) に置きます。このmigrationは次を行います。

1. 既存の非NULLパスを事前検査し、不正値があれば変更前に停止する。
2. `content-images` と `content-audio` を公開bucketとして定義する。
3. MIME typeをWebPとMP3へ限定する。
4. 公式bucketの旧クライアント書き込みpolicyを削除する。
5. 公式DBを認証利用者の読み取り専用GRANT・RLSへ狭める。
6. `example_contents` の新しいパスをCHECK制約で守る。
7. bucket、policy、GRANT、制約をmigration内で検証する。

本番適用前には、対象プロジェクト、既存Storage policy、既存bucket設定、全パス、DBのGRANT/RLSを読み取りで再確認します。本番適用とファイルアップロードは別の実行承認が必要です。

## 7. 確認方法

- `image_asset_path` と `audio_asset_path` が規則に一致すること。
- パス末尾のIDが `example_contents.id` と一致すること。
- 公開URLが画像・音声を取得できること。
- 認証利用者が公式DBを更新できないこと。
- `service_role` を使う運営処理だけがDBとStorageを書き換えられること。
- 画像・音声のNULLでSwiftUIの表示と操作が壊れないこと。
