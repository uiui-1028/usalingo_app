# 終わった資料

ここは、役目を終えた計画書と手順書の棚です。**いまの判断には使いません。**
「なぜそうしたか」をあとで確かめるために残しています。

| 棚 | 中身 |
|---|---|
| [plans/](plans/) | 終わった計画書と引き継ぎ文（USL-255、USL-295、USL-297、ゲスト学習記録の引き継ぎ） |
| [operations/](operations/) | 50語をAnkiと正本JSONから入れていたときの手順。手順が使う `scripts/prepare-official-content.py` と `prepare-official-media.py` は 2026-09-17 に削除した（Git の履歴にある） |
| [content/](content/) | 50語の抽出記録と正本JSON |

2026-09-17 に、それ以前の旧仕様・旧ワークフロー記録（35ファイル）を削除しました。
Git の履歴に残っているので、必要なら `git log --diff-filter=D -- docs/archive/` で探せます。

[`content-source-and-word-list-20260907.md`](../decisions/content-source-and-word-list-20260907.md) には
「`anki-50-extraction.md` は移動しない」と書いてあります。移動しない理由は、決定記録からのリンクが
切れるためでした。2026-09-17 に、リンクを直したうえで、ここへ移しました。
