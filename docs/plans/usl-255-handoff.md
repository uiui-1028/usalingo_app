# USL-255 引き継ぎ｜法務・ライセンス・クレジットの表示

作成日: 2026-09-01

対象: Notion [USL-255](https://app.notion.com/3bdc3d1f59e881a1a109c8549c87adca)
「実装｜法務・ライセンス・クレジットをアプリ内で確認できるようにする」

## いまの状態

| 項目 | 値 |
|---|---|
| status | **blocked** |
| owner | ai |
| worker_id | `codex-usl255-01a029`（lease は期限なし＝作業権は空いている） |
| work_branch | `codex/usl-255-legal-credits`（**リモートに存在しない**。未マージの作業は残っていない） |
| 関連 PR | [#26](https://github.com/uiui-1028/usalingo_app/pull/26)、[#28](https://github.com/uiui-1028/usalingo_app/pull/28)（どちらもマージ済み） |

**コードはできている。止まっているのは中身（実値）だけ。**
`ProfileDashboardView.swift` の `LegalView` / `LegalDocument.publishedDocuments` /
`OpenSourceLicenseView` / `AppInfo.swift` はすべて実装済みで、`origin/main` に入っている。

## これが M1 の最後の関門

USL-287「実行｜最初のビルドを TestFlight へ提出して内部テスターへ配る」は3件に
blocked されていた。うち2件は片づいた。

| 依存 | 状態 |
|---|---|
| USL-285 実機で初回起動から10枚回答までを確認 | **done**（2026-09-01、全項目合格） |
| USL-245 Anki migration の本番適用 | **done** |
| USL-255 法務・ライセンス表示 | **blocked ← ここだけ** |

USL-287 自体は `will`。USL-255 が done になれば、そのまま着手できる。

## blocked の理由（2026-08-28 時点、Notion の実施レポートより）

以下は当時の記録。1と3は 2026-09-01 に解消した（下の「確定した値」を見る）。

1. `docs/legal/published/` の事業者情報・所在地・施行日・素材出典・連絡先が**サンプル値**。
2. 公開先の Bubble 3ページ（`terms` / `privacy` / `credits`）が**未作成**。アプリはこの URL を開くので、
   ページが無ければリンク切れになる。
3. 素材ごとのライセンス台帳が未確認。
4. VoiceOver、Dynamic Type、実機でのリンク遷移、XCTest が未確認。

## 範囲が縮んだ（2026-09-01 時点の新情報）

USL-278 で「v0.1 は**現在の同梱教材で先に配る**」と決めた
（[usl-278-v01-release-scope.md](../decisions/usl-278-v01-release-scope.md)）。
その結果、クレジットに書くべき素材は次だけになった。

- 同梱デッキは `apps/ios-swiftui/UsalingoIOS/Resources/SampleDecks/toeic-basic.json` の**1本のみ**
  （100枚、`description` は「暫定データ」）。
- そのカードは `imageAssetPath` も `audioAssetPath` も**すべて null**。画像・音声の権利処理は v0.1 では発生しない。
- 外部パッケージ依存は**ゼロ**。`Resources/Licenses/` は空（`.gitkeep` のみ）で、これは依存が無いので正しい状態。

つまり「素材ライセンス台帳」は、**この同梱デッキ100語の出どころを1行決めるだけ**で足りる。
50語の正式教材・画像・音声の権利処理は M2 の USL-284 の仕事であり、USL-255 の解除条件ではない。

## 確定した値（2026-09-01、責任者の決定）

| 項目 | 確定値 |
|---|---|
| 事業者 | **河合 泰芽（個人）**。法人登記が無いため「合同会社」は名乗らない。文書中の一人称は「当方」 |
| 所在地 | 〒446-0042 愛知県安城市大山町2-15-18 |
| 問い合わせ窓口 | `support@usalingo.jp` |
| 電話番号 | **載せない**。表示義務は特定商取引法によるもので、有償取引が前提。Usalingo は全機能無料のため義務が無い。課金を入れるときに追加する |
| 版・施行日 | 第1.0版 ／ 2026年9月1日 |
| 裁判管轄 | 東京地方裁判所 → **名古屋地方裁判所**（所在地に合わせた） |
| 同梱100語の出どころ | **当方が生成AIを用いて作成した暫定データ**。NGSL・NAWL などの第三者リストは使っていない |
| データの所在 | Supabase 東京リージョン（`ap-northeast-1`）。国内保管であることを明記し、米国法人による取扱いの可能性を書いた |

これらは `docs/legal/published/` の3文書へ反映済み。アプリ側の定数
（`publishedVersion` / `publishedEffectiveDate` / `supportEmail`）は元から同じ値だったため、
**コードの変更は不要だった**。

## 残っている作業

### 人間にしかできないこと

| # | 作業 | 状態 |
|---|---|---|
| 1 | 法務3ページを公開する | **未作成**。Notion [USL-295](https://app.notion.com/3cec3d1f59e881f79968ffa0459b7350)。**2026-09-01 に方針変更**: Bubble をやめ、静的サイトを作って Vercel の無料枠で公開する。ドメインも取り直すため、アプリの `publishedBaseURL` も変わる。手順は [usl-295-handoff.md](usl-295-handoff.md) |
| 2 | 実機で VoiceOver・Dynamic Type・リンク遷移を確認する | 未実施（USL-285 と同じやり方でできる） |
| 3 | 法的な適否の専門家確認 | 未実施 |

### まだ確定していない2項目

| 項目 | どこ | いつ決まるか |
|---|---|---|
| 対象年齢 | プライバシーポリシー第7条 | App Store Connect への提出時（USL-287）に年齢区分を選ぶので、そこで確定する |
| 保有期間（バックアップからの消去期間） | 同 第9条 | Supabase のバックアップ保持設定を確認して書く |

どちらも `> [!NOTE] 確定待ち` として文書に残してある。サンプル値は残っていない。

## 最短の順番

```text
✅ 事業者情報・出典・施行日を確定（人間）
✅ 3文書へ反映（AI）
→ 静的サイトを作って Vercel で公開（USL-295）※ パスは /terms /privacy /credits
→ 公開URLに合わせて publishedBaseURL を直す（AI）
→ 実機でリンク遷移・VoiceOver・Dynamic Type を確認（人間）
→ USL-255 を done に（AI）
→ USL-287 TestFlight 提出へ（ここで対象年齢が決まる）
```

パス（`/terms`、`/privacy`、`/credits`）は動かせない。アプリが決め打ちで開くため。
ドメインは取り直すので、公開URLが決まったらアプリ側の `publishedBaseURL` を同じコミットで直す。

## 次のセッションへ渡すプロンプト

以下をそのまま新しいセッションへ貼る。

---

USL-255（実装｜法務・ライセンス・クレジットをアプリ内で確認できるようにする）を進めたい。
状況は `docs/plans/usl-255-handoff.md` にまとめてある。まずこれを読むこと。

要点だけ先に伝える。

- コードは実装済みで `origin/main` に入っている。文書の実値も 2026-09-01 に確定・反映済み。
- 残っているのは、Bubble の3ページ公開（人間）と実機でのリンク確認（人間）だけ。
- USL-255 は M1 の最後の関門で、これが done になれば USL-287（TestFlight 提出）に進める。
- Notion 上の worker_id は `codex-usl255-01a029` のまま残っているが lease は期限切れで、
  ブランチ `codex/usl-255-legal-credits` はリモートに存在しない。未マージの作業は無い。

やってほしいこと。

1. 法務3ページ（Notion USL-295）が公開されたか確認する。Bubble ではなく、リポジトリ内の
   静的サイトを Vercel で公開する方針に変わっている。詳細は `docs/plans/usl-295-handoff.md`。
2. 公開されたら、実機でプロフィール →「法務・ライセンス」から4行すべてをタップし、
   ページが開くこと、版と施行日が出ること、問い合わせでメールが起動することを確認してもらう。
   VoiceOver と Dynamic Type も同じ画面で確認する。やり方は USL-285 と同じ。
3. プライバシーポリシー第7条（対象年齢）と第9条（保有期間）は確定待ちのまま残っている。
   対象年齢は USL-287 の App Store Connect 提出時に決まるので、そこで文書へ書き戻す。
4. 完了したら Notion USL-255 に実施レポートを追記し、status を done にする。

守ること。

- `.agents/skills/usalingo-next-ticket` の作業権の手順に従い、着手前に lease を取り、
  書き込み前にもう一度 `worker_id` が自分のままであることを確認する。
- 法的な適否は AI が判断しない。専門家確認が要る箇所はそう書いて残す。
- 未承認の草案を正式文書として表示しない。
- 説明は小学生でもわかるように比喩的に、端的でシンプルに。

---

## 参照

- [milestones.md](milestones.md) — M1 / M2 の全体像とチケットの依存
- [external-package-adoption-plan.md](external-package-adoption-plan.md#領域1-法務ライセンス問い合わせバージョン) — 領域1 の詳細
- [usl-278-v01-release-scope.md](../decisions/usl-278-v01-release-scope.md) — v0.1 で配るもの
- [../legal/asset-and-privacy-inventory.md](../legal/asset-and-privacy-inventory.md) — 公開前の確認リスト7項目
- [../operations/testflight-release-checklist.md](../operations/testflight-release-checklist.md) — Apple 側の準備状況
