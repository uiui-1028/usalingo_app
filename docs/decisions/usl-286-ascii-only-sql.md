# USL-286 生成SQLをASCIIだけに限る

決定日: 2026-09-04

## 決めたこと

`scripts/prepare-official-content.py` が出すSQLは、**非ASCIIを1文字も含まない**。
日本語はPostgreSQLのUnicodeエスケープ `U&'\6311\6226'` で書く。生成時に
`assert_ascii_only` が検査し、1文字でも混じっていれば書き出さずに止める。

## なぜ

2026-09-04、本番で50語の差し替えを実行したところ、**日本語がすべて文字化けした**。

```
正しい:  e68c91 e688a6                    (挑戦)
本番:    c38a c3a5 c3ab c38a c3a0 c2b6    (Êåëʈ¶)
```

UTF-8のバイト列がMac Romanとして解釈され、そのまま保存されていた。

原因は経路にある。生成SQLをローカルで `pbcopy` し、ブラウザのSupabase SQL Editorへ
貼り付けて実行した。この受け渡しのどこかで文字コードの判定が外れた。SQL自体も
正本JSONも壊れていない。**壊れたのは「日本語を含むテキストを別のアプリへ渡す」工程だけ**である。

生成物をASCIIに限れば、経路がどの文字コードだと判断しても同じバイト列が届く。
根本の対策になる。

## そのとき何が起きたか

| | |
|---|---|
| 影響 | `words` 1-50 に紐づく意味73行、例文和訳50行、活用・関連の各50行 |
| 気づき方 | 実行後の確認で等価比較が `false` を返し、`encode(convert_to(...),'hex')` で確定 |
| 復旧 | 差し替えSQLが同じトランザクションで取っていた `usl286_pre_merge_snapshot` から完全復元 |
| 復旧後 | hexで照合し、`挑戦する／挑戦`・`心配する／関心、懸念` とも事故前と一致 |
| 利用者データ | 学習履歴88件・タグ3件はどちらも無傷（`words` 行を消さない設計のため） |

控えがSQLの文字列リテラルではなく**DB内のSELECTで作られていた**ことが、復旧できた理由である。
人が値を書き写す案を採らなかった判断が、結果的に事故を救った。

## 検証

使い捨てDB `usl286_test` に本番と同じ形の試験台を作り、エスケープ版SQLを流して、
正本JSONとバイト単位で突き合わせた。

- 意味 **73件 完全一致**
- 例文和訳 **50件 完全一致**
- `render-sql` の出力も `isascii() == True`

## 残る注意

- **確認は必ずバイトで行う。** 画面上の文字は、表示側の解釈で正しく見えることがある。
  `encode(convert_to(値,'UTF8'),'hex')` を使う。
- ASCII化は生成SQLだけの対策である。正本JSON、Notion、文書は日本語のままでよい。
  問題は「SQLを別アプリへ貼る」経路に限られる。
- `docs/content/target-1900-0001-0050.json` は影響を受けていない。事故は本番DBの中だけで起きた。

## 根拠

- [`usl-286-repo-owned-content.md`](usl-286-repo-owned-content.md)（正本JSONの決定）
- [`../operations/import-official-content-production.md`](../operations/import-official-content-production.md)（本番手順）
