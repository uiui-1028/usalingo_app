# 既製品採用 実行計画書（法務表示・画像キャッシュ・学習記録・オフライン）

状態: **領域0 完了。領域1 実装済み（開発機でのビルド確認待ち）。領域2以降は未着手**

判定（2026-08-30）: 領域ごとに、いまのマイルストーンに要るかどうかを判定した。

| 領域 | 判定 |
|---|---|
| 領域0 土台 | 完了 |
| 領域1 法務・ライセンス | **要る（M1）**。人に配るなら必要。Notion USL-255 |
| 領域2 画像キャッシュ | **要る（M2）**。画像が実機へ乗るときに一緒に入れる |
| 領域3 学習記録 | **要らない（延期）**。ただし今の表示は事実と違う値を出す。下の注意を見る |
| 領域4 オフライン | **要らない（延期）**。M1・M2のどちらにも要らない |

根拠は [../decisions/plan-scope-20260830.md](../decisions/plan-scope-20260830.md)、
マイルストーンは [milestones.md](milestones.md) を見る。

作成日: 2026-08-27

対象: `apps/ios-swiftui/`、`supabase/migrations/`

> [!IMPORTANT]
> この計画の目的は、機能を増やすことではなく、**自作しなくてよい部分を自作しないこと**です。Usalingoの差別化（学習アルゴリズム、スワイプ回答、イラスト体験、Adaptive Space）は自作を続けます。汎用処理は既製品に任せます。

## 前提の変更

「外部パッケージへ依存せず、Apple標準フレームワークで構成する」という方針は撤回しました。新しい方針は [`technology-stack.md`](../operations/technology-stack.md#外部パッケージの方針) にあります。

## 全体像

| 順番 | 領域 | 主な作業 | 新しい依存 | migration | 規模の目安 |
|---|---|---|---|---|---|
| 0 | 土台 | 依存を足せる状態にする、ライセンス収集の仕組み | LicensePlist | なし | 小 |
| 1 | 法務・アカウント下部 | 空の枠を埋める、問い合わせ、バージョン表示 | なし | なし | 小（ただし人間の判断が要る） |
| 2 | 画像キャッシュ | `AsyncImage` を置き換える、先読み | Nuke | なし | 中 |
| 3 | 学習記録 | 復習ログ表を作る、ヒートマップを作り直す | なし | あり | 中 |
| 4-1 | オフライン（読み取り） | 公式コンテンツのローカルキャッシュ | なし（SwiftData） | なし | 中 |
| 4-2 | オフライン（書き込み） | 学習結果の送信待ち行列 | なし（SwiftData） | あり | 大 |

この順番には理由があります。

- 依存を増やすほどライセンス表示の義務が増えるので、**収集の仕組み（0）を最初に**入れます。あとから集めると必ず漏れます。
- 領域1は画面がすでにあり、コード量が最小です。しかも公開準備の律速なので、早く動かす価値があります。
- 領域2で入れるディスクキャッシュは、領域4のオフライン体験の土台になります。
- 領域3と4-2はデータベースを変えるので、後ろに置きます。

## 領域0: 土台

### やること

1. Swift Package を追加したとき `Package.resolved` がGitへ入ることを確認する。
   - 保存先は `apps/ios-swiftui/UsalingoIOS.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`。
   - `.gitignore` の `.swiftpm/` はこのパスに当たらないため、追加設定は不要（確認済み）。
2. LicensePlist を導入し、依存のライセンス一覧を**生成物として**作る。
   - 手で書いた一覧は必ず古くなります。生成に寄せます。
   - 生成した一覧をアプリ内の「ライセンス」画面から読む（領域1と合流）。
3. `Services/` に薄いラッパを置く習慣を決める。呼び出し側のViewが外部パッケージの型を直接使わないようにします。あとで差し替えるときの被害範囲がラッパ1枚で済みます。

### 完了のしるし

- パッケージを1つ追加してコミットすると、`Package.resolved` が差分に現れる。
- ライセンス一覧の生成コマンドが `apps/ios-swiftui/README.md` に書かれている。

### 進捗（2026-08-27）

| 項目 | 状態 |
|---|---|
| `Package.resolved` がGitへ入るか | `git check-ignore` で無視されないことを確認済み。追加設定なし |
| LicensePlist の設定 | `apps/ios-swiftui/license_plist.yml` を追加 |
| 生成コマンド | `scripts/generate-licenses.sh`（`--check` で古さの検出も可） |
| 出力先 | `apps/ios-swiftui/UsalingoIOS/Resources/Licenses/Acknowledgements.md` |
| 手順の記載 | `apps/ios-swiftui/README.md` の Dependencies と Licenses |
| ラッパ規約 | [`technology-stack.md` の「薄いラッパの置き方」](../operations/technology-stack.md#薄いラッパの置き方) |

**開発機（macOS）でやること。** LicensePlist を入れて `sh scripts/generate-licenses.sh` を1回実行し、生成された `Acknowledgements.md` をコミットします。いま依存はゼロなので、生成される一覧は空です。それが正しい状態です。

1つ目の完了のしるしは、依存がまだ無いため確認できていません。領域2でNukeを追加するときに、同じコミットへ `Package.resolved` と `Acknowledgements.md` の両方が現れることで確認します。

生成物をアプリ内の「ライセンス」画面から読む配線は、計画どおり領域1で行います。`Resources/Licenses/` をバンドルへ入れるための `project.pbxproj` の変更も、そのときにまとめて行います。

## 領域1: 法務・ライセンス・問い合わせ・バージョン

**判定: 要る（M1）。** 人に配るなら必要。Notion USL-255 が対応し、
「実行｜最初のビルドをTestFlightへ提出して内部テスターへ配る」の前提になっている。

### 現状（コードで確認済み）

- [`ProfileDashboardView.swift`](../../apps/ios-swiftui/UsalingoIOS/Features/Profile/ProfileDashboardView.swift) の `LegalView` は**すでに完成しています**。利用規約・プライバシー・ライセンス・クレジットの4行、公開済み文書の一覧、`ContentUnavailableView` まであります。
- ただし `LegalDocument.publishedDocuments` が空配列のため、いま全部が「正式版は公開準備中です。」と表示されます。
- 文面のPDFは [`docs/legal/source/`](../legal/source/) に5点あります（利用規約、プライバシーポリシー、AIGCガイドライン、特定商取引法、著作権について）。
- 問い合わせ先は未実装。アプリバージョンは `Info.plist` にキーがあるだけで、画面に出していません。

つまり**この領域で新しく書くコードはごくわずか**です。残っているのは主に「決めること」と「置くこと」です。

### やること

| # | 作業 | 誰が |
|---|---|---|
| 1 | PDF 5点を現行実装に合わせて直す。課金、ユーザー投稿・共有、プロフィール画像、13歳基準、端末識別IDの収集は現行コードに存在しないため削る。収集項目は [USL-249の表1](../legal/asset-and-privacy-inventory.md) をそのまま使う | 人間（責任者） |
| 2 | 会社名・住所・問い合わせ窓口・配信国・対象年齢を確定する | 人間（責任者） |
| 3 | 公開先を決めて置く。App Store Connect はプライバシーポリシーの**URL**を求めるため、アプリ内表示だけでは足りない。Supabase Storage の公開バケット、またはGitHub Pagesなどの静的ページに置く | 人間＋AI |
| 4 | `LegalDocument.publishedDocuments` に版・施行日・URLを入れる | AI |
| 5 | 問い合わせ行を実装する。まず `mailto:` の `Link` で十分。本文にアプリ版・iOS版・機種を差し込む | AI |
| 6 | `Services/AppInfo.swift` を作り、`CFBundleShortVersionString` と `CFBundleVersion` を読んでプロフィール最下部に表示する | AI |
| 7 | 領域0で作ったライセンス一覧を「ライセンス」行から開けるようにする | AI |

### 自作しないもの

- ポリシー文面をゼロから書くこと。既存PDFの校正から始めます。
- ライセンス一覧の手作業収集。

### 完了のしるし

- 4行すべてがタップでき、どれも「公開準備中」ではない。
- 問い合わせをタップするとメールが起動し、本文に版と機種が入っている。
- 画面最下部にバージョンが出る。
- 領域2でNukeを追加したあと、ライセンス一覧にNukeが自動で増える。

### 注意

法的な適否は専門家が判断します。[USL-249](../legal/asset-and-privacy-inventory.md) の「公開前の確認リスト」7項目がそろうまで、旧草案をそのまま公開版として出しません。

### 進捗（2026-08-27）

公開文書の正本を [`docs/legal/published/`](../legal/published/) にMarkdownで作りました。PDFを直接書き換えていないのは、公開先がWebページ（URL）であり、PDFでは App Store Connect が求めるURLにならないためです。`docs/legal/source/` のPDFは2025-08-15の旧草案として残します。

**この計画の表の「誰が」を、実際にはこう分けました。**

| # | 作業 | 状態 |
|---|---|---|
| 1 | 文面を現行実装に合わせる | ✅ 済。課金、共有、プロフィール画像、13歳基準、端末識別IDを削除し、アカウント削除を追記 |
| 2 | 会社名・住所・窓口・配信国・対象年齢 | ⚠️ **サンプルデータを置いた**。責任者による確定待ち |
| 3 | 公開先を決めて置く | ⚠️ URLは決定（下記）。Bubble側のページ作成は未実施 |
| 4 | `publishedDocuments` に版・施行日・URLを入れる | ✅ 済 |
| 5 | 問い合わせ行（`mailto:`、本文に版と機種） | ✅ 済 |
| 6 | `Services/AppInfo.swift` とバージョン表示 | ✅ 済 |
| 7 | ライセンス一覧を「ライセンス」行から開く | ✅ 済。外部URLではなくアプリ内画面にした |

**公開先。** 当初は Bubble のページを使う予定でしたが、2026-09-01 に方針を変え、リポジトリ内の静的サイトを Vercel の無料枠で公開することにしました。ドメインも取り直します。パスは `/terms`、`/privacy`、`/credits` のままで、アプリはこの形で決め打ちで開きます。作業は Notion USL-295、手順は [usl-295-handoff.md](usl-295-handoff.md) にあります。

**サンプルデータの扱い。** 会社所在地、施行日、素材の出典欄はサンプルです。旧PDFにあった住所と電話番号は、公開リポジトリの検索可能なテキストとして置き直すことを避け、プレースホルダにしました。問い合わせ先は個人宛ではなく `support@usalingo.jp` という役割アドレスにし、`AppInfo.supportEmail` の1か所で変えられるようにしています。

**いま公開しない文書。** 特定商取引法に基づく表示（課金が未実装）と AI生成コンテンツガイドライン（生成・共有機能が未実装）は、該当機能を入れるときに作ります。無い機能の規約を先に出すと、実装と文書が食い違ったまま公開することになります。

**未実施。** この作業環境にXcodeが無いため、ビルドとXCTestは実行していません。`AppInfoTests` を追加済みで、開発機での実行が必要です。

## 領域2: 画像キャッシュ

**判定: 要る（M2）。** 画像と音声が実機へ乗る「実装｜画像と音声を配信できる形で登録する」の
直後に入れる。Notion の「実装｜画像のディスクキャッシュを入れる」が対応する。

### 現状

`AsyncImage` を3か所で使っています。

- [`StudyCardView.swift:34`](../../apps/ios-swiftui/UsalingoIOS/Features/Study/StudyCardView.swift) — 学習カードのイラスト
- [`WordListView.swift:596`](../../apps/ios-swiftui/UsalingoIOS/Features/Words/WordListView.swift) — 単語詳細
- [`WordListView.swift:743`](../../apps/ios-swiftui/UsalingoIOS/Features/Words/WordListView.swift) — 一覧のサムネイル

`AsyncImage` はディスクキャッシュを持たず、`URLCache` の既定設定に任せます。イラストが主役で1900枚規模のこのアプリでは、通信量、体感速度、機内モードでの見え方すべてに効きます。ここを自作すると、ディスク上限、失効、同時実行、先読みまで面倒を見ることになり、典型的に重い作業になります。

### 採用するもの

**Nuke / NukeUI**（MIT）。SwiftUI用の `LazyImage`、ディスクキャッシュ、`ImagePrefetcher` が揃っています。Kingfisherでも同じことができますが、Nukeの方が小さく、SwiftUI前提の設計です。

WebPはiOSが標準で読めるため、追加のデコーダは不要です。

### やること

1. `Services/ImageLoading/CardImageLoader.swift` を作り、`ImagePipeline` の設定（ディスク上限、有効期限）を1か所にまとめる。
2. `CardImage(url:)` という薄いラッパViewを作る。欠損時の代替表示は現在の挙動をそのまま移す。
3. 上の3か所を `CardImage` に置き換える。
4. 学習セッションで次の数枚を先読みする。[`StudySessionView.swift`](../../apps/ios-swiftui/UsalingoIOS/Features/Study/StudySessionView.swift) がカードの並びを持っているので、先頭から3〜5枚のURLを `ImagePrefetcher` へ渡す。
5. プロフィールに「画像キャッシュを削除」を置く。

サムネイルとデッキ表紙は先読みの対象にしません。見られない画像を取りに行く割合が高く、通信量の無駄になります。

### 完了のしるし

- 機内モードにしても、一度見たカードの画像が表示される。
- 同じカードを2回目に開いたとき、ネットワーク要求が発生しない。
- 既存のXCTestが通る。

### 気をつけること

ディスク使用量。上限を決め、削除手段を画面に置くところまでを1セットにします。

## 領域3: 学習記録（ヒートマップ・ストリーク）

> [!WARNING]
> **判定: 要らない（M1・M2の外へ延期）。** ただし延期しても、下に書いた `last_reviewed_at` の
> 問題は消えない。いま画面に出ている過去の学習日は事実と違う。配る前に「表示しない」「参考値と
> 明記する」「領域3を前倒しする」のどれかを選ぶ。この選択は Notion の
> 「決定｜v0.1で配るものと配らないものを決める」で行う。

### 現状

- [`StudyService.swift`](../../apps/ios-swiftui/UsalingoIOS/Services/StudyService.swift) の `fetchStudyStats` が `currentStreak` と `reviewedDays` を返します。
- `ProfileDashboardView` の `HeatmapTile` が直近14日を、緑か灰色の2値で表示します。

### 先に直すべき問題

`reviewedDays` は `user_card_progress.last_reviewed_at` から作られています。この列は**カードごとに最後の1回しか残りません**。

- 同じ日に何回復習しても1件として数えられます。
- 昨日復習したカードを今日もう一度復習すると、昨日の記録は消えます。

つまり現在のヒートマップは、過去の学習日を正しく表せません。表示範囲を伸ばすほど、この誤りが目立ちます。復習ログの表が存在しないことは `supabase/migrations/` で確認済みです。

### 対応

**復習ログ表を追加します。** Ankiの `revlog` と同じ考え方です。

```text
public.review_log
  id, user_id, card_id, reviewed_at, is_correct, client_review_id (unique)
```

`client_review_id` を UNIQUE にしておくと、領域4-2の再送で二重登録を防げます。ここで先に入れておくと、あとで作り直さずに済みます。

### やること

1. migration で `review_log` を作る。RLSは本人の行のみ。既存データからの初期埋めは `last_reviewed_at` の1行だけにとどめる（それ以上は復元できません）。
2. `StudyService` の回答保存に `review_log` への追加を足す。Undoのときはその行を消す。
3. 集計を `review_log` の日別件数に変える。件数が少ないうちはクライアント側で数えて構いません。
4. `HeatmapTile` を作り直す。濃淡4段階、直近180日、横スクロール、月ラベル、VoiceOverで「8月27日 12件」と読める。
5. 「学習日数」を `review_log` の日付の種類数にする。

描画そのものはGitHubのcontribution graphと同じ形です。SwiftUIの実装例が多数あるので参考にしますが、**外部パッケージにはしません**。100行程度で書ける上、見た目をUsalingo側で調整したいためです。

### 完了のしるし

- 同じ日に同じカードを2回復習すると、その日の件数が2になる。
- Undoすると、その日の件数が減る。
- 日をまたぐテストデータで、ストリークと学習日数が期待どおりになる（XCTestを追加）。

## 領域4: オフライン

**判定: 要らない（M1・M2の外へ延期）。** 内部テスターへ配ってから、実際に要望が出た時点で
順番を決め直す。

**この領域が一番危険です。双方向同期エンジンは自作しません。既製品も、必要になるまで入れません。**

3段階に分け、必要なところで止めます。

### 4-1 読み取りキャッシュ（今回やる）

公式コンテンツ（デッキ、カード、単語、例文）は運営しか書き換えません。**利用者が書かないので、衝突が起きません。** ここだけなら安全に作れます。

- `Models/Local/` にSwiftDataのキャッシュ用モデルを置く。既存の `Codable` モデルは変えない。
- `DeckService` と `StudyService` に「まずキャッシュ、取れたらサーバで更新」を挟む。
- 画像と音声は領域2のディスクキャッシュがそのまま効く。

SwiftDataはiOS 17標準なので、依存は増えません。SQLを直接書きたくなったときはGRDBが代替候補です。

### 4-2 書き込みの送信待ち行列（次点）

学習結果をローカルへ順番に積み、通信できるようになったら順に送ります。1人が1台で使う前提なら衝突しません。守るのは順序と、二重送信しないことだけです。領域3で入れた `client_review_id` がここで効きます。

同期状態は画面に常時表示しません（[core-workflow-requirements](../product/workflow.md) で対象外と決めています）。失敗が続いたときだけ知らせます。

### 4-3 本格的な双方向同期（今回やらない）

複数の端末で同時に学習して初めて必要になります。そのときはPowerSyncなどの既製品を検討し、**自作しません**。

### 完了のしるし（4-1と4-2）

- 機内モードで、一度開いたデッキの学習を最後まで進められる。
- 通信が戻ると、その結果がサーバへ反映される。
- 同じ回答が二重に登録されない。

### 進め方

4-1と4-2は必ず別のブランチに分け、4-1だけ先にマージします。まとめて出すと、問題が起きたときにどちらが原因か分からなくなります。

## この計画に含めないもの

次も既製品を使うべき領域ですが、別の計画にします。

- 課金（RevenueCat）
- 通知
- クラッシュ・利用ログ（Sentry / TelemetryDeck）
- CI/CDとApp Store提出の自動化（GitHub Actions、fastlane）
- 1900語の画像・音声の投入パイプライン

## 進め方の約束

生成AIの利用コストを抑えるために、次を守ります。

- 1領域 = 1ブランチ = 1プルリクエスト。
- 依存を追加する回は「追加するだけ」でプルリクエストを切る。置き換えは次の回。
- 採用したライブラリについて、公式サンプルの該当箇所を短く `docs/` へ写す。AIがAPIを推測して間違え、直す往復が消えます。
- 着手前に、その領域の「完了のしるし」を先に確認する。

## 見直す条件

- 採用したパッケージの保守が止まったとき。
- ライセンス条件が表示だけで満たせなくなったとき。
- 複数端末での同時学習が要件になったとき（4-3の判断へ進む）。
- 法務文書の確定が遅れ、領域1が公開の妨げになったとき（順番を入れ替える）。

## 影響する場所

- [`docs/operations/technology-stack.md`](../operations/technology-stack.md)
- [`docs/legal/asset-and-privacy-inventory.md`](../legal/asset-and-privacy-inventory.md)
- `apps/ios-swiftui/UsalingoIOS/Features/Profile/`
- `apps/ios-swiftui/UsalingoIOS/Features/Study/`
- `apps/ios-swiftui/UsalingoIOS/Features/Words/`
- `apps/ios-swiftui/UsalingoIOS/Services/`
- `supabase/migrations/`
