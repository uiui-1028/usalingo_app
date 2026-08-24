# Usalingo ワークフロー策定の記録

> [!IMPORTANT]
> ここは、Usalingoの使い方と動きを決めるための記録場所です。**Webで確認した事実**と**Usalingoの仮説**を分け、仮説を勝手に仕様へ変えません。

## このフォルダーの役割

- [`../usalingo-simple-product-plan.md`](../usalingo-simple-product-plan.md): 変えない大きな方向
- [`../usalingo-workflow-planning-execution-plan.md`](../usalingo-workflow-planning-execution-plan.md): 決める順番と方法
- このフォルダー: 調査した事実、感想、候補、決定、未確認事項

> [!NOTE]
> 資料にある例や仮説は、記録で `決定` になったときだけワークフローへ採用します。競合の見た目や文章はコピーせず、Usalingoの目的に合う動きだけを選びます。

## 進める順番

| 段階 | 作る記録 | 完了のしるし | 状態 |
|---|---|---|---|
| 1 | 競合4アプリの調査 | 公式Webの事実、仮説、未確認を分離 | Web調査済み |
| 2 | パターン整理 | 採用候補と不採用候補に理由がある | 仮説あり・未決定 |
| 3 | 最短成功フロー | 一本の流れを決定 | 未着手 |
| 4 | MVP分岐 | 必須の分かれ道と失敗時の戻り先を決定 | 未着手 |
| 5 | 表側一覧 | 必要な画面・情報・操作を決定 | 未着手 |
| 6 | 裏側状態図 | 状態・出来事・保存・失敗時の動きを決定 | 未着手 |
| 7 | 最終ワークフロー | 表側と裏側を一つにつなぐ | 未着手 |

## 記録のルール

各項目へ、次のどれかを明記します。

- `事実`: 実際に見た、操作した、確認できたこと
- `仮説`: Web上の事実から考えた、まだ検証していない案
- `感想`: 使った人が感じたこと
- `候補`: まだ選んでいない案
- `決定`: 人間が選んだUsalingoの方針
- `未確認`: まだ確認できていないこと

AIは記録を整理して2〜3案を出し、人間は大切な入口だけを選びます。決定後の文書整理と矛盾確認はAIが進めます。

## 記録ファイル

### 1. 競合調査

- [`01-competitor-research/README.md`](01-competitor-research/README.md) — 4社比較とUsalingoの仮説
- [`01-competitor-research/anki.md`](01-competitor-research/anki.md)
- [`01-competitor-research/quizlet.md`](01-competitor-research/quizlet.md)
- [`01-competitor-research/tanzam.md`](01-competitor-research/tanzam.md)
- [`01-competitor-research/mikan.md`](01-competitor-research/mikan.md)

### 2〜7. Usalingoの決定

- [`02-patterns.md`](02-patterns.md)
- [`03-shortest-success-flow.md`](03-shortest-success-flow.md)
- [`04-mvp-branches.md`](04-mvp-branches.md)
- [`05-visible-parts.md`](05-visible-parts.md)
- [`06-hidden-states.md`](06-hidden-states.md)
- [`07-final-workflow.md`](07-final-workflow.md)

後の段階は、前の段階が決まるまで確定しません。

## 次に行うこと

> [!TIP]
> 4アプリをすべて人力で調べる必要はありません。まず、AIが作った[4社比較と仮説](01-competitor-research/README.md)から、最短成功フローの候補を作ります。

実機確認が必要になった場合も、原則として次の3点だけに絞ります。

1. 初回起動から最初の問題まで、何を選ばされるか。
2. 1問の中で、イラスト、例文、回答、評価がどの順で出るか。
3. 学習を終えたあと、次回はどこから再開するか。

<details>
<summary>Markdownで使う「箱」の書き方</summary>

```markdown
> [!NOTE]
> 確認済みの補足です。

> [!IMPORTANT]
> 今回の中心となる情報です。

> [!WARNING]
> 未確認や注意が必要な情報です。
```

長い補足は、この部分のように `<details>` で折りたためます。

</details>
