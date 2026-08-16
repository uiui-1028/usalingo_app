# Usalingo Notion設定

最終確認日: 2026-08-16。Notionへ書く前に必ず再取得し、現在のスキーマを優先する。

## 対象

- プロジェクト: `Pro｜Usalingo Ver.2.0`
  - `https://app.notion.com/p/39fc3d1f59e8802eace0f44d0786cd8e`
- Epic DB: `Pro｜Usalingo｜01｜Workspace`
  - DB: `https://app.notion.com/p/57ec3d1f59e8833699bb81d485f9ae65`
  - Data source: `collection://c78c3d1f-59e8-8281-99ac-07a0bc11c45c`
- 共通課題DB: `Pro｜Usalingo｜02｜Taskspace`
  - DB: `https://app.notion.com/p/ff7c3d1f59e882c4899181c6181bbf3a`
  - Data source: `collection://7c0c3d1f-59e8-83f8-8958-07b0b1cf4a03`

検索結果にはVer.1.0の同名DBも出る。上のVer.2.0配下のURLを使う。

## Epicの主なプロパティ

- `epic`: タイトル
- `fase`: `ver.2.0`
- `area`: UIUX / Content / Marketing / Development / Requirements / Enviroment / Legal
- `目的・目標`: 短い成果説明
- `status`: status DBへのrelation

## 共通課題の主なプロパティ

- `task`: タイトル
- `type`: task / bug / research / poc / idea / decision
- `epic`: Epic DBへのrelation、1件
- `status`: status DBへのrelation、1件
- `priority`: priority DBへのrelation、1件
- `owner`: human / ai / joint
- `approval`: not-needed / waiting / approved
- `worker_id`: 作業権を持つAIの一意な名前
- `lease_until`: 作業権の期限。タイムゾーン付きISO 8601日時を使い、`date:lease_until:is_datetime=1` にする。
- `work_branch`: Gitブランチまたはworktreeなど、作業を分離した場所
- `blocked_by`: 同じTaskspace内の前提課題へのrelation
- `source`: Knowledge DBへのrelation
- `runday`, `enday`: 日付。日程が決まっていない場合は空にする。

## Relationの値

Status:

- will: `https://app.notion.com/21cc3d1f59e880baac37c00d7055d707`
- run: `https://app.notion.com/21cc3d1f59e8807f8f1de6ea75153784`
- done: `https://app.notion.com/21cc3d1f59e880c282fef49f49ce7c12`
- reserve: `https://app.notion.com/21cc3d1f59e880ca853dd0c33bec805d`
- aborted: `https://app.notion.com/21cc3d1f59e8800a9a80d3a7aa3c2247`
- review: `https://app.notion.com/3b6c3d1f59e880eea066c44b5e2c360b`
- blocked: `https://app.notion.com/3b6c3d1f59e8806ca455f8ac1497e6a3`

共同作業用プロパティ:

- owner: human（人間が実施）/ ai（AIが実施）/ joint（共同）
- approval: not-needed（入口の選択不要）/ waiting（着手候補）/ approved（人間が着手を選択済み）
- blocked_by: 先に完了する必要がある課題。なければ空。
- source: 根拠となるKnowledge。該当文書がなければ空にし、必要に応じて先にKnowledgeを作る。

## AIレビュー中心の運用

2026-08-12以降は、人間が完成品を毎回レビューする運用をやめる。

- 人間: AIが示した2〜3件から、次に着手する課題を選ぶ。変えてはいけない条件があれば入口で伝える。
- AI: 選択後の調査、設計、作業、テスト、レビュー、修正、完了報告、Notion更新を行う。
- `will` + `approval=waiting`: 人間が選べる着手候補。
- `will` + `approval=approved`: 人間が選択済みで、AIが取得できる課題。
- `run` + 有効な `lease_until`: `worker_id` のAIが作業している課題。
- `review` + 期限なし: AIレビューの取得待ち。
- `review` + 有効な `lease_until`: `worker_id` のAIが受け入れ条件、差分、テスト、危険を確認中。人間の確認待ちには使わない。
- `done`: AIレビューに合格し、証拠と残る危険を記録した課題。
- `blocked`: 必須の環境、権限、外部状態がなくAIだけでは完了できない課題。解除条件を書く。

データ削除、本番DB変更、公開、課金、外部送信など、戻しにくい操作は別途実行承認を得る。これは完成品レビューではなく安全上の権限確認である。

## 複数AIの作業権

- `worker_id`: AIごとに異なる短いID。例: `codex-8f31a2`
- `lease_until`: 取得時は現在から30分後。作業中は20分以内ごとに延長する。例: `2026-08-15T06:30:00Z`。
- `work_branch`: 原則 `codex/usl-<番号>-<短い名前>`。同じ作業ツリーを複数AIで共有しない。
- 別AIの期限が有効なら、そのチケットを使わない。
- 取得直後、重要な書き込み前、状態変更前にページを再取得し、`worker_id` が自分か確認する。
- 完了、停止、レビュー引き渡しでは期限を空にする。
- 期限切れを引き継ぐ場合は、元のブランチと差分を確認してから担当を書き換える。

取得候補は `owner=ai` または `joint` に限る。`owner=human` は自動取得しない。

Notionは厳密な排他ロックではない。短い期限と再確認で重複を減らし、Gitブランチまたはworktreeでコード衝突を隔離する。

### AIが取得候補を探すSQL

`now_utc` には現在のUTC日時を渡す。通常の課題フローではSQL照会を着手前と完了後の
2回までにする。`blocked_by`の確認を別照会にせず、同じSQLで未完了の依存を除外する。

```sql
WITH tasks AS (
  SELECT *
  FROM "collection://7c0c3d1f-59e8-83f8-8958-07b0b1cf4a03"
)
SELECT candidate.url, candidate."userDefined:id", candidate.task,
       candidate.status, candidate.owner, candidate.approval,
       candidate.priority, candidate.worker_id,
       candidate."date:lease_until:start", candidate.work_branch,
       candidate.blocked_by
FROM tasks AS candidate
WHERE candidate.owner IN ('ai', 'joint')
  AND candidate.approval = 'approved'
  AND candidate.status LIKE ?
  AND (
    candidate."date:lease_until:start" IS NULL
    OR datetime(candidate."date:lease_until:start") <= datetime(?)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM json_each(COALESCE(candidate.blocked_by, '[]')) AS dependency
    LEFT JOIN tasks AS blocker ON blocker.url = dependency.value
    WHERE blocker.url IS NULL OR blocker.status NOT LIKE ?
  )
ORDER BY CASE
    WHEN candidate.priority LIKE '%21cc3d1f59e88148a7dff0bd84957295%' THEN 1
    WHEN candidate.priority LIKE '%21cc3d1f59e8815ca1cfd35ad1850231%' THEN 2
    WHEN candidate.priority LIKE '%21cc3d1f59e881428be5e481b2971473%' THEN 3
    WHEN candidate.priority LIKE '%21cc3d1f59e8817cbc0ce4c2cf5d4552%' THEN 4
    WHEN candidate.priority LIKE '%21cc3d1f59e8819b9503dc98179531a8%' THEN 5
    ELSE 99
  END,
  candidate."userDefined:id" ASC
LIMIT 10
```

- 実装候補の1つ目の引数: `%21cc3d1f59e880baac37c00d7055d707%` (`will`)
- レビュー候補の1つ目の引数: `%3b6c3d1f59e880eea066c44b5e2c360b%` (`review`)
- 2つ目の引数: `now_utc`
- 3つ目の引数: `%21cc3d1f59e880c282fef49f49ce7c12%` (`done`)

完了後の2回目は、同じSQLの`approval = 'approved'`を
`approval IN ('approved', 'waiting')`へ変える。`approval`を結果へ含め、承認済みと
承認待ちを別SQLに分けない。`approved`を先に並べ、その中でPriority、Issue ID順にする。
レビュー途中の次候補照会は行わない。3回目以降が必要な例外は
`docs/rules/codex-credit-optimization.md`の「TaskspaceのSQL予算」に従う。

### 作業権を取るプロパティ

1回の `update_properties` で次をまとめて更新し、直後にページを再取得する。

```json
{
  "worker_id": "codex-8f31a2",
  "date:lease_until:start": "2026-08-15T06:30:00Z",
  "date:lease_until:is_datetime": 1,
  "work_branch": "codex/usl-235-card-migration",
  "status": ["https://app.notion.com/21cc3d1f59e8807f8f1de6ea75153784"]
}
```

レビュー取得時は `status` を `review` のURLのままにする。作業権を返すときは `date:lease_until:start` を `null` にする。

Priority:

- P1 最優先: `https://app.notion.com/21cc3d1f59e88148a7dff0bd84957295`
- P2 高: `https://app.notion.com/21cc3d1f59e8815ca1cfd35ad1850231`
- P3 中: `https://app.notion.com/21cc3d1f59e881428be5e481b2971473`
- P4 低: `https://app.notion.com/21cc3d1f59e8817cbc0ce4c2cf5d4552`
- P5 検討中: `https://app.notion.com/21cc3d1f59e8819b9503dc98179531a8`

## 命名

課題タイトルは `動作｜対象` にする。

- `調査｜古い説明書を全部リストにする`
- `修正｜学習結果の取り消しを保存にも反映する`
- `検証｜音声方式を小さく試す`
- `決定｜オフライン対応の範囲を決める`
- `将来案｜学習履歴をグラフで見せる`

typeと日本語の先頭語を一致させる必要はないが、意味がずれないようにする。

## 書き込みの安全ルール

1. 検索、fetch、重複照会を先に行う。
2. Data source IDを親に使う。DBページIDをData sourceとして扱わない。
3. relationはページURLの配列で設定する。
4. 選択肢を変える場合は既存選択肢と色をすべて保持する。
5. 作成後に再照会する。
