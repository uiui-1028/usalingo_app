---
name: usalingo-next-ticket
description: UsalingoのVer.2.0 Taskspaceから着手可能な1件を取得し、最新origin/mainから分離した専用ブランチで調査、実装、テスト、AIレビュー、正確なcommit、push、GitHub PR作成、Notion完了報告まで自律的に進める。「次のチケットを進めて」「Notionから取って作業して」「同じ作業を繰り返して」または $usalingo-next-ticket / /usalingo-next-ticket と依頼されたときに使う。PRのマージ、削除、force push、公開済み履歴の書き換え、本番変更は含まない。
---

# Usalingo Next Ticket

着手可能な1件を、混線のないブランチから未マージのPRまで届ける。候補がない、競合した、または必須条件を満たせない場合は、安全に停止して解除条件を示す。

## 優先するルール

1. リポジトリの `AGENTS.md` と `docs/rules/codex-credit-optimization.md` を最初に読む。
2. Notionの現在のスキーマ、ユーザーの最新決定、このスキル、`../usalingo-project-manager/SKILL.md` の順に優先する。project-managerはNotion設定と文書テンプレートに使い、削除済みの `approval` など古い記述は採用しない。
3. Supabase、GitHub、文書など別スキルの対象に入ったら、利用可能な該当スキルも使う。
4. 現行アプリは `apps/ios-swiftui/` とし、Flutter資料を実装の正本にしない。

## この呼び出しで許可されること

対象チケットの範囲に限り、次を追加確認なしで完了まで進める。

- 読み取り、`git fetch`、状態確認
- 専用branchの作成と、必要な場合だけworktreeの作成
- Notionの作業権、進捗、レビュー、完了報告の更新
- ローカルの調査、編集、ビルド、テスト、AIレビュー
- 対象だけのstage、1目的のcommit、通常のpush、GitHub PR作成
- 作成したPRのbase、head、差分、状態の再確認

次はこの呼び出しだけでは許可しない。必要になった直前に、対象と影響を示して明示承認を得る。

- PRのmerge、branch/worktreeの削除
- force push、公開済み履歴の書き換え
- 本番DB・Auth・Storage・Edge Functionsの変更、本番データ書き込み
- データ削除、公開・リリース、課金、GitHub/Notion以外への外部送信

## 取得条件

Ver.2.0 Taskspace `collection://7c0c3d1f-59e8-83f8-8958-07b0b1cf4a03` だけを使う。

- `status=will`
- `owner` が `human` ではない（空欄を含む）
- `blocked_by` がすべて `done`
- 他AIの有効な `lease_until` がない

`status=will` を着手許可として扱い、Priority、Issue IDの順で選ぶ。`owner=human` だけはAIが取得しない。`owner` が空欄でも取得対象に含める。SQLでは `owner IS NULL OR owner = '' OR owner != 'human'` として判定する。`reserve` は将来候補、`review` はレビュー工程なので、このスキル呼び出しだけで `will` へ変更しない。`owner=human`、`reserve`、`review`、有効期限内の他AI作業、未完了依存へ条件を広げない。`approval` は照会・更新・判断に使わない。

候補SQLは非humanの `will` をWHERE句で取得し、依存とleaseを `dependencies_ready`、`lease_ready`、`ready` として計算する。未完了依存や有効なleaseをWHERE句で消してはいけない。`ready=1` を先頭に並べ、最初の `ready=1` だけを取得する。これにより「will自体が0件」と「willはあるが、すべて待機中」を区別する。

## 開始時のGit分離

1. `git status --short --branch`、現在branch、既存worktreeを確認し、既存差分をユーザーの作業として保護する。
2. Notion接続の `self` をfetchし、正しいワークスペースと `query_data_sources` の利用可否を確認する。
3. Taskspaceスキーマをfetchし、非humanの `will` と各行の `ready` 判定を1回の `query_data_sources` SQLで取得する。SQLは `../usalingo-project-manager/references/notion-setup.md` の現行例を使う。
4. `will` が0件ならその事実を報告する。`will` はあるが `ready=1` が0件なら、上位候補と未完了の `blocked_by` または有効なleaseを解除条件として報告する。どちらの場合も何も変更しない。
5. 先頭候補のページ本文をfetchし、受け入れ条件と危険操作を確認する。
6. `git fetch origin` を実行し、開始点を最新の `origin/main` にする。ローカル `main` が古くても、その上から作業branchを作らない。
7. クライアント名を小文字にした接頭辞を使い、チケットごとに `<client>/usl-<番号>-<短い名前>` の新規専用branchを作る。Cursorは `cursor/`、Codexは `codex/` を使う。既存branchを再利用せず、同名が存在する場合は一意な接尾辞を付ける。
8. 通常は現在のcheckoutを使う。checkoutがcleanで、別の作業に使用中でなければ、最新の `origin/main` から専用branchを作って切り替える。
9. `main` へ直接変更・commitしない。既存checkoutがdirty、別チケットを作業中、または複数AIが並行作業中の場合だけ、既存状態を守るため別worktreeを使う。その場でpull、rebase、reset、stashして既存作業を動かさない。
10. worktreeが必要な場合はリポジトリ外、原則 `/private/tmp/usalingo-<番号>-<一意値>` に作る。リポジトリ内の `.codex-worktrees/` を作成・stageしない。
11. 分離先にignoredな `Config/Local.xcconfig` が必要なら、秘密値をコピーせず `Local.xcconfig.example` 相当の一時設定を使う。一時設定、DerivedData、Simulator成果物をcommitしない。
12. `<client>-<一意な文字列>` の `worker_id`、30分後のタイムゾーン付き `lease_until`、`work_branch`、`status=active` を1回で更新する。
13. 直後にページを再取得し、`worker_id`、`lease_until`、`work_branch` が自分の値であることを確認する。競合したら編集せず停止する。

## 最小Notionフロー

1. Notion接続とTaskspaceスキーマを確認する。
2. 着手前の1回のSQLで取得条件を満たす候補を取得する。候補が0件なら何も変更せず終了する。
3. 先頭候補の本文、受け入れ条件、最新決定、危険操作を確認する。チケットが最新の人間決定と矛盾する場合は実装せず停止する。
4. 専用branchを作った後、一意な `worker_id`、30分後の `lease_until`、`work_branch`、`status=active` を1回で更新する。
5. 直後に再取得し、自分の作業権であることを確認する。競合したら編集せず撤退する。
6. 20分以内ごと、commit、push、PR、Notion状態変更の直前に作業権を再確認・延長する。
7. 完了または外部要因による停止では、自分が作業権を持つことを確認してから `lease_until` を空にする。作業権が別AIへ移っていたら上書きしない。
8. チケットの対象だけを調査・変更する。現行アプリは `apps/ios-swiftui/` を基準にする。
9. 対象テストを実行し、必要なら関連テストまで広げる。
10. `active` から `review` へ移し、受け入れ条件、実差分、テスト、未確認事項を別工程としてAIレビューする。
11. 不備は修正して再検証する。合格時だけ完了レポートを追記し、`done`、終了日、空の `lease_until` を設定する。
12. 必須環境や権限がなく完了できなければ、解除条件を記録して `blocked` とし、作業権を返す。
13. 完了後の1回のSQLで、`status=will` かつ `owner` が `human` ではない（空欄を含む）次候補をまとめて取得し、上位2〜3件を報告する。

`query_data_sources` は原則、着手前と完了後の2回だけ使う。同じ制限エラーを繰り返さない。

## 実装とAIレビュー

1. チケット本文、関連仕様、対象コード、直接関係するテストだけを読む。
2. 受け入れ条件を確認できる最小差分を実装する。無関係な整理を混ぜない。
3. 対象テストを先に実行し、影響に応じて関連テスト、全体テストへ広げる。
4. 環境エラーは原因を切り分け、安全な代替経路で再試行する。必須テストが失敗したまま完了扱いにしない。
5. `status=review` にし、依頼、受け入れ条件、実差分、テストログ、秘密・生成物・対象外混入を別工程として確認する。
6. 不備を自分で修正して再検証する。人間へ通常の品質確認を丸投げしない。

## commit・push・PR

コードまたは追跡対象文書の差分がある場合だけ実行する。空commitや空PRを作らない。

1. `git diff --check`、`git status --short`、`git diff --name-status` を確認する。
2. `.codex-worktrees/`、`xcuserdata`、`.xcuserstate`、`.DS_Store`、`supabase/.temp/`、DerivedData、一時設定、秘密値、無関係な文書を除外する。
3. `git add <対象path>` または必要なhunkだけをstageする。`git add .`、広いglob、未確認の一括stageを使わない。
4. `git diff --cached --check` と `git diff --cached --name-status` を確認し、受け入れ条件に必要な変更だけか再確認する。
5. Issue IDと目的が分かる1目的のcommitを作る。`git show --stat --name-status HEAD` でメッセージと内容が一致することを確認する。
6. push前にleaseと最新 `origin/main` を再確認する。未公開branchなら必要に応じて安全にrebaseする。公開済みbranchでforce pushが必要になる場合は停止して承認を得る。
7. `git push -u origin <branch>` を実行し、`base=main` のPRを作る。PR本文に概要、対象ファイル、テスト、本番未確認事項を分けて書く。
8. PRがopenで、base、head、変更ファイルが意図どおりであることをGitHub側で再確認する。PRをmergeしない。
9. コード変更ではPR作成と検証まで成功した後に完了レポートを追記し、`status=done`、終了日、空の `lease_until` を設定する。pushまたはPR作成が必須なのに認証・権限で失敗した場合は、ローカル実装済みと配布未完了を分け、解除条件を示して `blocked` にする。
10. 完了後の2回目のSQLで次の適格候補を上位2〜3件だけ取得して報告する。自動で次の候補へ着手しない。

## 停止条件

次の場合は推測で進めず、既存作業を保持して停止する。

- 候補がない、Notion接続・利用枠が使えない
- leaseを取得できない、または別AIへ移った
- チケットが最新の人間決定と矛盾する
- 必須の仕様、権限、テスト環境がなく安全に完了できない
- 秘密値、無関係な変更、内容と不一致なcommitを発見した
- merge、削除、force push、本番変更が必要になった

`blocked` は外部の解除条件がある場合だけ使う。単に未実装なら `will` のままにする。

## マージ依頼を別途受けた場合

1. PRのbase/head、差分、レビュー、CI、未確認事項を最新状態で確認する。
2. ユーザーがそのPRのmergeを明示した場合だけmergeする。
3. `merged=true` とmerge commitが `origin/main` に含まれることを確認する。
4. ローカル `main` はcleanな場合だけfast-forwardする。dirtyなら触らず、遅れていることを報告する。
5. branch/worktreeは自動削除しない。

## 完了報告

次を短く分けて報告する。

- 実装した内容とPR URL
- 実行して成功したテスト
- 本番で未確認の内容
- merge待ち、blocked、残件のいずれか

追加条件がある場合は同じ行へ続ける。

`$usalingo-next-ticket 本番変更はせず、SwiftUIの課題を優先して`