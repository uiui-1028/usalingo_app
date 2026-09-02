# USL-286 50語の正本をAnkiからリポジトリへ移す

決定日: 2026-09-02

対象: TARGET-1900の原本番号1〜50（50語、意味73件、例文50件）

## 決めたこと

50語の教材データの正本を、ローカルAnkiから
[`../content/target-1900-0001-0050.json`](../content/target-1900-0001-0050.json) へ移す。
以後の検査・SQL生成・本番投入はこのJSONを読む。**Ankiの原本は変更しない。**

## なぜ

権利者（河合 泰芽）から次の指示があった。

- Ankiアプリ内のデータは変更してほしくない
- データを抽出して、プロジェクト内にコピーを置きたい

これまで正本がローカルAnkiにあったため、次の問題があった。

- 教材を直すには、権利者本人のAnkiアプリを触るしかない
- 17,070ノートを含む個人の学習環境が、製品のビルド依存になっている
- 誰がいつ何を直したかがGitに残らない
- 別の作業者・別の環境で同じデータを再現できない

[`../operations/import-official-content.md`](../operations/import-official-content.md) は当初
「中間JSONはGitへ追加せず一時領域だけに置く」としていたが、その理由は
「権利確認前の素材だから」であった。USL-284で権利確認が完了したため、この制約は解消している。

## 公開範囲について

`https://github.com/uiui-1028/usalingo_app` は**公開リポジトリ**である。このJSONをコミットすると、
50語の単語・意味・例文・和訳・語源が公開される。

この点を権利者へ明示したうえで、権利者の判断として公開リポジトリへ置くことを選んだ。
公開は取り消しがきかない（削除しても、その間のクローン・フォーク・キャッシュは残る）。

権利は引き続き権利者に帰属する。[`../legal/published/credits.md`](../legal/published/credits.md)
第1節の「無断で複製、改変、転載、配布、商業利用することは禁止」は変更していない。
公開リポジトリに置くことと、利用条件を緩めることは別である。

なお `reserved` の USL-143「単語リストのオープンソース化」は、この決定とは別に扱う。
今回はリポジトリへ置いただけで、オープンソースライセンスは付与していない。

## あわせて直した3件

抽出時に出ていた「複数senseの語で例文をpriority 1へ機械が仮接続した」警告22件を、
全件を人手とAIで照合した。19件は正しく、3件を直した。Ankiではなくこのコピー側で直している。

| 位置 | 単語 | 例文 | 直した内容 |
|---|---|---|---|
| 17 | concern | This issue concerns everyone.（この問題は全員に関係する。） | 動詞の定義を `心配する` → `関係する、心配させる` へ。品詞は合っていたが、定義そのものが誤りだった |
| 23 | limit | The speed limit is 50 km/h.（制限速度は時速50kmだ。） | senseの並び順を `動詞／名詞` → `名詞／動詞` へ。例文は名詞用法 |
| 35 | challenge | This task is a big challenge.（この課題は大きな挑戦だ。） | 同上 |

`limit` と `challenge` を「並び替え」で直したのは、`prepare-official-content.py` の検査が
`example must reference the priority-1 meaning` を強制しているためである。例文のつなぎ先だけを
変えることはできない。

`increase`（位置2）は例文が他動詞「売上を増やす」で定義が「増加する」だが、品詞も意味の系統も
同じであるため、そのままとした。

例文・画像・音声は変更していない。したがって本番Storageへ登録済みの150素材の作り直しは不要である。

## いま含めていないこと

- **media本体**。画像50・音声100の実ファイルはリポジトリへ入れていない。所在は
  ローカルAnkiの `collection.media` と、本番Supabase Storage（USL-288で登録済み、SHA-256検証済み）。
  したがってテキストはAnkiから切り離せたが、**mediaの再生成は依然としてAnkiに依存する**。
  完全に切り離すには約2.6 MBのmediaをどこへ置くかを別途決める必要がある。
- 51語目以降。今回の対象は1〜50のみ。
- 本番DBへの投入。手順と承認は別（USL-286の本番手順は未整備）。

## 確認方法

```sh
python3 scripts/prepare-official-content.py validate \
  --input docs/content/target-1900-0001-0050.json

python3 scripts/prepare-official-content.py render-sql \
  --input docs/content/target-1900-0001-0050.json \
  --output /private/tmp/usalingo-286-content.sql
```

`valid: 50 entries, positions 1-50, required fields and media references present` が出ること。

## 根拠

- [`../content/anki-50-extraction.md`](../content/anki-50-extraction.md)（抽出規則の正本）
- [`usl-284-material-rights.md`](usl-284-material-rights.md)（権利確認）
- [`../operations/import-official-content.md`](../operations/import-official-content.md)（投入手順）
