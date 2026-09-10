# USL-297 引き継ぎ｜意味を複数ならべて表示し、例文が優先度1以外でも絵と音を出す

作成日: 2026-09-10

対象: Notion [USL-297](https://app.notion.com/p/3d4c3d1f59e88145b50df696381d59ea)
根拠: [教材の正本と単語リスト](../decisions/content-source-and-word-list-20260907.md)、
[milestones.md](milestones.md) M2

## 1. 何をしたいか

1単語の意味を**すべて並べて表示**する。例文は**そのうち1つの意味**に付く。

```text
DB                          画面
① 経営する  (priority 1)    run
② 走る      (priority 2)    経営する ／ 走る
   └ 例文がこちらに付く      I run every morning.
                            私は毎朝走ります。
```

「この例文はどの意味のものか」は**いまは示さない**（決定ずみ。将来または開発の途中で足す）。

## 2. いま壊れていること

`apps/ios-swiftui/UsalingoIOS/Models/WordCard.swift` の `WordRecord.toCard()`。

```swift
let meaning = wordMeanings?
    .sorted { ($0.priority ?? 9999) < ($1.priority ?? 9999) }
    .first
guard let meaning else { return nil }
let example = meaning.exampleContents?.first
```

**優先度が最も高い意味を1件だけ取り、その意味に付いた例文だけを見ている。**

例文が優先度1以外の意味に付いている単語は、`example` が `nil` になる。
`WordCard` は画像と音声も例文から取っているため、
**例文・訳・イラスト・音声の4つが同時に消える。**

```swift
sentenceEnglish: example?.sentenceEnglish,
sentenceJapanese: example?.sentenceJapanese,
imageAssetPath: example?.imageAssetPath,
audioAssetPath: example?.audioAssetPath,
```

単語と意味だけが残った、**絵の無い、音の出ないカード**になる。

## 3. 2段に分ける

この課題には、**波及ゼロで直せるバグ**と、**8か所へ波及する仕様変更**が混ざっている。
分けないと、バグ修正が仕様変更の完了待ちになる。

### 第1歩｜例文が消えるのを止める（波及ゼロ）

`toCard()` の中だけで閉じる。型もビューも変えない。

- 表示する意味は、いまのまま優先度1のもの
- **例文は、その単語のすべての意味から探す。** 優先度順に見て、最初に見つかった例文を使う

これだけで「絵と音が消える」は止まる。既存の呼び出し側は1行も変わらない。

### 第2歩｜意味を複数ならべる（8か所へ波及）

`WordCard.meaning: String` と `partOfSpeech: String?` は**どちらも単数**。
複数の意味を正しく持たせるには型を変える必要がある。品詞は意味ごとに変わるため
（`light` ＝ 明かり／名詞、軽い／形容詞）、意味と品詞は組にして持つ。

波及する場所は次のとおり。

| ファイル | 行 | 何をしているか |
|---|---:|---|
| `Features/Study/StudyCardView.swift` | 68 | `Text(card.meaning)` |
| `Features/Study/StudyCardView.swift` | 90, 112 | 品詞チップの出し分け |
| `Features/Study/WordCardContent.swift` | 54 | `WordPartOfSpeech(englishOrJapanese: card.partOfSpeech)` |
| `Features/Words/WordDetailSheet.swift` | 423, 543, 646 | 詳細画面の意味と品詞 |
| `Features/Words/WordListRowViews.swift` | 81 | 一覧の行 |
| `Features/Words/WordListViewModel.swift` | 48 | **検索**。`meaning` を小文字化して部分一致 |
| `Features/Words/WordEditSheet.swift` | 22 | **利用者による上書き編集** |
| `Services/LocalStudyDataSource.swift` | 454-455 | 同梱デッキから `WordCard` を作る |
| `Models/DeckFile.swift` | 75 | 同梱デッキJSONの `meaning: String` |

## 4. 気をつけること

1. **利用者の上書きは1つの文字列のまま。**
   `user_word_overrides.definition_jp` は `text` 列が1本
   （[migration](../../supabase/migrations/20260618195500_create_user_word_overrides.sql)）。
   利用者が意味を書き換えたら、それは**並んだ意味の全体を置き換える1つの文字列**として扱う。
   意味ごとの上書きは今回やらない。DBを変えることになるため。

2. **検索を壊さない。**
   `WordListViewModel` は `meaning` の部分一致で検索している。
   複数意味になっても、**すべての意味が検索に引っかかる**こと。

3. **同梱デッキJSONの形を勝手に変えない。**
   `DeckFile` はゲストが最初に触るサンプル。形を変えるなら同梱ファイルも同じコミットで直す。
   変えずに済むなら変えない。

4. **DBスキーマは変えない。**
   V5の `word_senses`（何行でも持てる、`priority` で順番）と
   `example_contents.sense_id`（どの意味の例文か）で、すでに表現できている。
   migrationは不要。

5. **通信は増えない。**
   `Services/StudyService.swift` の問い合わせは、すでに全部の意味とその例文を取得している。

   ```text
   id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,
     example_contents(id,sentence_en,sentence_jp,image_asset_path,audio_asset_path))
   ```

   取ってきたものを捨てているだけ。クエリを変える必要はない。

6. **並べる順は `priority` の昇順。区切りは「／」。**

## 5. 確認方法

- `UsalingoIOSTests/WordCardTests.swift` に、**例文が優先度2の意味に付いた `WordRecord`** を足し、
  `toCard()` が例文・訳・画像・音声を返すことを確かめる。いまのテストにこの形は無い
- 複数意味の単語で、意味が `priority` 順に並ぶ
- 意味が1つの単語の見た目が、いままでと変わらない
- 検索で、2つ目以降の意味でもヒットする
- 既存テストが通る
- **UIが変わるため、実機またはシミュレータのスクリーンショットを残す**

## 6. 決まっていること

| 項目 | 決定 |
|---|---|
| 表示する意味 | すべて。`priority` 順 |
| 例文が付く意味 | 1単語につき1つ。シートの `sense_id` で決まる |
| どの意味の例文かの表示 | **いまは示さない** |
| DBスキーマ | 変えない |
| 意味ごとの上書き編集 | 今回やらない |

## 7. この課題の位置

`blocked_by` は無い。**Epicの中でいちばん先に着手する実装。**

これを直さないまま1000語を入れると、絵の出ないカードが出たときに
**「データが悪い」のか「アプリが取り落としている」のか区別できなくなる**。

後続: [USL-305](https://app.notion.com/p/3d4c3d1f59e8813ba95adb4797c05d1e)
（類義語と語源の仮表示をやめ、本物のデータにつなぐ）がこの課題を待っている。
