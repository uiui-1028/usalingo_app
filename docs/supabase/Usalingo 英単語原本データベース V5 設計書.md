# Usalingo 英単語原本データベース V5 設計書

## 1. このドキュメントの目的

Usalingoで使用する英単語データの**原本データベース**について、現在の設計方針をまとめる。

旧V4をそのまま改修するのではなく、V4を保存したまま、整理した新しい原本として**V5**を構築する。

V5では、厳密なデータベース正規化だけを目的にせず、

- 人間がGoogle Spreadsheetで確認・編集しやすい
- AIがまとめてデータを生成しやすい
- APIから直接セルへデータを書き込みやすい
- 将来Supabaseへ安全に変換しやすい
- Usalingo独自の「コンセプト英単語帳」を拡張しやすい

ことを重視する。

---

# 2. 全体方針

Usalingoではデータを大きく2種類に分ける。

## Google Spreadsheetが上位となる教材データ

英単語そのものや、意味、例文、発音など。

```text
Google Spreadsheet
        ↓
     変換・同期
        ↓
Supabase
        ↓
   Usalingoアプリ
```

Google Spreadsheetを**原本・正本**として扱う。

Supabase側の教材データは、アプリが読み取りやすい形に変換された運用用データとする。

---



## Supabaseだけで管理する運用データ

ユーザーがアプリを利用することで発生する情報はSpreadsheetでは管理しない。

例：

- アカウント
- プロフィール
- デッキ
- カード
- 学習履歴
- 正解・不正解
- 復習予定
- お気に入り
- ユーザー設定

これらはSupabaseのみで管理する。

---



# 3. Usalingoの教材コンセプト

Usalingoは、単純に「英単語と日本語訳を覚える」だけの英単語帳ではない。

中心となる考え方は、

> **同じ英単語・意味を、さまざまなコンセプトの例文・画像・音声で楽しみながら学習する**

ことである。

例えば `run = 走る` という1つの意味に対しても、

```text
run
└─ 走る
   ├─ シンプル
   │   └─ I run every morning.
   │
   ├─ ホラー
   │   └─ Something was running behind me.
   │
   ├─ 恋愛
   │   └─ She ran into his arms.
   │
   └─ ファンタジー
       └─ The knight ran toward the castle.
```

のように複数の教材コンテンツを持てる。

この構造をV5設計の中心とする。

---



# 4. 正規化の基本方針

すべての情報を別シートに分解することはしない。

判断基準は、

> **1つに対して、複数の独立した情報を持つ必要があるか**

とする。

例えば、

```text
1単語
↓
複数の意味
```

があるため、単語と意味は分離する。

また、

```text
1つの意味
↓
複数のコンセプト例文
```

があるため、意味と例文も分離する。

一方、CEFRのようにUsalingo内では最終的に1つの値へ決定する情報は、別シートにせず列として保持する。

---



# 5. V5のシート構成

シートは役割ごとにグループ化し、以下の命名規則を採用する。


| グループ    | シート                       | 役割          |
| ------- | ------------------------- | ----------- |
| Core    | `01_core_words`           | 見出し語        |
| Core    | `01_core_senses`          | 意味・品詞・CEFR  |
| Content | `02_content_concepts`     | コンセプト一覧     |
| Content | `02_content_examples`     | コンセプト別例文・画像 |
| Audio   | `03_audio_pronunciations` | 単語発音・単語音声   |
| Audio   | `03_audio_example_audio`  | 例文音声        |
| Extra   | `04_extra_forms`          | 語形          |
| Extra   | `04_extra_relations`      | 類義語・反意語など   |


大分類は次の4種類。

```text
01_core
    英単語そのものの基本情報

02_content
    Usalingoで表示する教材コンテンツ

03_audio
    発音・音声関連

04_extra
    補助的な単語情報
```

---



# 6. 01_core_words



## 役割

英単語そのものを管理する最上位のシート。

1つの見出し語につき1レコードとする。

## カラム


| カラム          | 内容      |
| ------------ | ------- |
| `word_id`    | 単語の固定ID |
| `word_text`  | 英単語     |
| `created_at` | 作成日時    |
| `updated_at` | 更新日時    |


例：


| word_id | word_text |
| ------- | --------- |
| 1001    | run       |
| 1002    | apple     |
| 1003    | bank      |


`word_id`は単語を識別する基準となる。

単語文字列ではなく、このIDを使って他のシートと接続する。

---



# 7. 01_core_senses



## 役割

1つの単語が持つ**複数の意味**を管理する。

例えば `run` は、

```text
run
├─ 走る
└─ 運営する
```

という複数意味を持つため、意味ごとに別レコードとする。

## カラム


| カラム                 | 内容       |
| ------------------- | -------- |
| `sense_id`          | 意味の固定ID  |
| `word_id`           | 対応する単語ID |
| `priority`          | 意味の優先順位  |
| `part_of_speech_en` | 英語品詞     |
| `part_of_speech_jp` | 日本語品詞    |
| `definition_jp`     | 日本語の意味   |
| `cefr`              | CEFRレベル  |


例：


| sense_id | word_id | priority | part_of_speech_en | definition_jp | cefr |
| -------- | ------- | -------- | ----------------- | ------------- | ---- |
| 2001     | 1001    | 1        | verb              | 走る            | A1   |
| 2002     | 1001    | 2        | verb              | 運営する          | B1   |


---



# 8. CEFRの扱い

CEFRは複数の辞書や資料によって異なる可能性がある。

しかしUsalingoでは、

> **最終的にUsalingoとして1つのCEFRを決める**

方針とする。

そのため、CEFR専用シートは作らず、

```text
01_core_senses.cefr
```

に直接保持する。

使用値は基本的に、

```text
A1
A2
B1
B2
C1
C2
```

とする。

以前検討していた `cefr_state` は削除する。

値がまだ決まっていない場合は空欄とする。

---



# 9. 02_content_concepts



## 役割

Usalingo独自の「コンセプト」を管理する。

例：


| concept_id | concept_code | concept_name |
| ---------- | ------------ | ------------ |
| 1          | simple       | シンプル         |
| 2          | horror       | ホラー          |
| 3          | romance      | 恋愛           |
| 4          | fantasy      | ファンタジー       |




## カラム


| カラム            | 内容           |
| -------------- | ------------ |
| `concept_id`   | コンセプトID      |
| `concept_code` | アプリ内部で使うコード  |
| `concept_name` | 人間向け表示名      |
| `description`  | コンセプトの説明     |
| `is_active`    | 現在使用するコンセプトか |


以前検討した `sort_order` は使用しない。

基本的な並び順には `concept_id` を使用する。

---



# 10. 02_content_examples



## 役割

意味ごとの例文・日本語訳・画像を管理する。

Usalingoでは、ここが主要な教材コンテンツとなる。

## 構造

```text
word
 ↓
sense
 ↓
example
 ↓
concept
```

例えば、

```text
run
└─ 走る
   ├─ simple
   ├─ horror
   ├─ romance
   └─ fantasy
```

のように、同じ意味に複数の例文を登録できる。

## カラム


| カラム                | 内容        |
| ------------------ | --------- |
| `example_id`       | 例文ID      |
| `sense_id`         | 対応する意味ID  |
| `concept_id`       | コンセプトID   |
| `sentence_en`      | 英文        |
| `sentence_jp`      | 日本語訳      |
| `image_asset_path` | 画像ファイルのパス |
| `image_state`      | 画像データの状態  |
| `display_order`    | 同条件内での表示順 |


例：


| example_id | sense_id | concept_id | sentence_en                      |
| ---------- | -------- | ---------- | -------------------------------- |
| 3001       | 2001     | 1          | I run every morning.             |
| 3002       | 2001     | 2          | Something was running behind me. |
| 3003       | 2001     | 3          | She ran into his arms.           |


---



# 11. データ状態の考え方

画像や音声など、一部の項目では値が存在しない理由を区別する。

使用する状態は以下。


| 状態               | 意味            |
| ---------------- | ------------- |
| `present`        | 値が存在する        |
| `blank`          | まだ作成・入力していない  |
| `not_applicable` | そのデータでは不要     |
| `unverified`     | 値はあるが確認できていない |


例えば、

```text
image_asset_path = ""
image_state = blank
```

なら、

> 「画像をまだ作っていない」

という意味になる。

一方、

```text
image_asset_path = ""
image_state = not_applicable
```

なら、

> 「この例文では画像を使用しない」

という意味になる。

すべてのカラムに状態列を付けるのではなく、必要な項目にだけ使用する。

---



# 12. 03_audio_pronunciations



## 役割

単語そのものの発音と音声を管理する。

Usalingoでは将来的に、1単語に対して複数音声を用意する予定である。

そのため、IPAを `words` の1列に直接保存せず、発音専用シートとして分離する。

## 例

```text
run
├─ US / default
├─ US / male
├─ US / female
└─ UK / default
```

現時点では1つの音声しか用意しなくても、将来追加できる構造にする。

## カラム


| カラム                | 内容        |
| ------------------ | --------- |
| `pronunciation_id` | 発音レコードID  |
| `word_id`          | 単語ID      |
| `accent`           | US / UKなど |
| `ipa`              | IPA表記     |
| `ipa_state`        | IPAの状態    |
| `audio_asset_path` | 単語音声      |
| `voice_label`      | 音声の種類     |
| `is_primary`       | 基本音声か     |
| `display_order`    | 表示順       |


例：


| pronunciation_id | word_id | accent | ipa   | voice_label |
| ---------------- | ------- | ------ | ----- | ----------- |
| 4001             | 1001    | US     | /rʌn/ | default     |
| 4002             | 1001    | UK     | /rʌn/ | default     |


---



# 13. 03_audio_example_audio



## 役割

例文音声を管理する。

例文も将来的に複数音声を持てる設計とする。

```text
I run every morning.
├─ default
├─ male
├─ female
└─ character
```

現時点では1例文につき1音声でもよい。

## カラム


| カラム                | 内容     |
| ------------------ | ------ |
| `example_audio_id` | 例文音声ID |
| `example_id`       | 対応する例文 |
| `audio_asset_path` | 音声ファイル |
| `audio_state`      | 音声の状態  |
| `voice_label`      | 音声種類   |
| `is_primary`       | 標準音声か  |
| `display_order`    | 表示順    |


---



# 14. 04_extra_forms



## 役割

複数形・過去形・比較級などの語形を管理する。

当初は、

```text
run
runs
ran
run
running
```

をそれぞれ別レコードにする正規化方式を検討した。

しかし、1万単語に対して最大5万件程度まで増える可能性があり、Usalingoでは語形を個別レコードとして操作する必要性が低い。

そのため、**1単語1レコード＋JSON**形式を採用する。

## カラム


| カラム          | 内容     |
| ------------ | ------ |
| `word_id`    | 単語ID   |
| `forms_json` | 語形JSON |


例：

```json
{
  "third_person": "runs",
  "past": "ran",
  "past_participle": "run",
  "present_participle": "running"
}
```

Spreadsheet上では1セルに保存する。

アプリ側またはSupabase変換処理でJSONを分解して利用する。

現時点ではシート構造のみを作成し、実データ作成は後回しでもよい。

---



# 15. 04_extra_relations



## 役割

類義語・反意語・派生語・関連語を管理する。

当初は、

```text
big
→ large
```

のように、関連先も `words.word_id` へ接続する方式を検討した。

しかしこの方法では、

- 関連語がまだwordsに登録されていない
- 関連語のIDを探す必要がある
- AI生成後に接続作業が必要
- 大量データでは管理コストが高い

という問題がある。

そのためrelationsも、**1単語1レコード＋JSON**形式とする。

## カラム


| カラム              | 内容      |
| ---------------- | ------- |
| `word_id`        | 単語ID    |
| `relations_json` | 関連語JSON |


例：

```json
{
  "synonyms": [
    "large",
    "huge"
  ],
  "antonyms": [
    "small",
    "tiny"
  ],
  "derivatives": [
    "bigness"
  ],
  "related": [
    "size"
  ]
}
```

関連語が `01_core_words` に存在する必要はない。

AIが単語単位でまとめて生成した結果を、そのまま保存しやすいことを優先する。

---



# 16. JSONを採用する場所

V5では原則として正規化するが、以下の2つは意図的にJSONを使用する。

```text
04_extra_forms
04_extra_relations
```

理由は、

> **個々の値をDB上で独立して管理するメリットより、1単語単位でまとめて扱うメリットの方が大きいため**

である。

これは設計上の妥協ではなく、Usalingoの用途に合わせた意図的な非正規化とする。

---



# 17. IDの基本ルール

以下のIDは、データ同士を接続する重要な値である。

```text
word_id
sense_id
concept_id
example_id
pronunciation_id
example_audio_id
```

基本ルール：

- IDは安定した固定値とする
- 一度使用したIDを別のデータへ再利用しない
- 単語文字列ではなくIDで接続する
- IDをSpreadsheet関数に依存させない
- Google Sheets固有関数を主キー生成に使用しない

AIやAPIからデータを入力する場合も、このルールを守る。

---



# 18. AI・APIによるデータ入力

Google Spreadsheetは、人間が手入力するだけのDBではない。

将来的には、

- AIが生成したCSVやJSONをコピー＆ペースト
- APIからGoogle Sheetsへ直接書き込み
- AIエージェントによる大量生成
- Pythonなどによる一括登録

を想定する。

そのためV5では、

> 「AI生成 → 人間確認 → 公開」

という複雑な承認状態管理はDB構造には組み込まない。

AI由来か、人間入力かを細かく記録するシートも現段階では作らない。

まずは**データ本体をシンプルに管理すること**を優先する。

---



# 19. 出典情報

現時点では `sources` シートを作らない。

理由は、基本的な教材データをAIによって生成する予定であり、個別の辞書・サイト・文献を原本として管理する必要性が低いため。

将来的に、

- Oxford
- Cambridge
- 独自コーパス
- 外部教材
- ライセンス付きデータセット

などを混在させる場合に再検討する。

---



# 20. validationについて

V5 Spreadsheetには現時点で専用の `validation` シートを置かない。

まずは原本構造を完成させる。

ただし、将来的には同期・出力処理の中で、

- ID重複
- 存在しないword_id
- 存在しないsense_id
- 空欄
- JSON構文エラー
- 重複単語
- 未接続例文

などを自動確認することを想定する。

つまり、

> **検証は必要だが、原本の1シートとして持つ必要はまだない**

という方針。

---



# 21. Supabase出力シートについて

現時点では、

```text
export_words
export_word_meanings
export_example_contents
```

などの出力専用シートは作成しない。

V5原本設計が固まった後に、実際のSupabaseスキーマに合わせて変換処理を設計する。

原則として、

```text
Google Spreadsheet
        ↓
   変換プログラム
        ↓
     Supabase
```

とする。

SpreadsheetとSupabaseを完全に同じ構造にする必要はない。

---



# 22. V5全体のデータ関係

全体像は以下。

```text
01_core_words
│
├── 01_core_senses
│      │
│      └── 02_content_examples
│              │
│              ├── 02_content_concepts
│              │
│              └── 03_audio_example_audio
│
├── 03_audio_pronunciations
│
├── 04_extra_forms
│       └── JSON
│
└── 04_extra_relations
        └── JSON
```

最も重要な基本構造は、

```text
word
 ↓
sense
 ↓
example
```

である。

Usalingo独自の要素として、

```text
example
 ↓
concept
```

が加わる。

さらに単語・例文それぞれに複数音声を持てる。

---



# 23. 優先順位



## 最重要

```text
01_core_words
01_core_senses
02_content_concepts
02_content_examples
```

Usalingoの教材構造そのもの。

## 重要

```text
03_audio_pronunciations
03_audio_example_audio
```

コンセプト英単語帳としての体験を強化する。

## 補助

```text
04_extra_forms
04_extra_relations
```

単語理解を補助するデータ。

---



# 24. V5設計の基本思想

V5では、

> **「正規化されていること」より、「Usalingoでどう使うか」を優先する。**

意味や例文のように、独立して増えたり切り替えたりするデータは正規化する。

一方、語形や類義語のように「単語についてまとめて見る情報」はJSONにまとめる。

また、

> **今必要ではない管理機能を先に作らない**

ことも重要な方針とする。

そのため現段階では、

- sources
- validationシート
- Supabase出力シート
- AI生成履歴
- 承認ワークフロー
- ID管理専用シート

などは作らない。

必要になった時点で追加する。

---



# 25. V4からV5への移行方針

旧V4はそのまま保存する。

V4を直接書き換えてV5にするのではなく、新しいV5原本を別に作成する。

```text
V4
旧原本
保存

   ↓ 必要なデータを移行

V5
新原本

   ↓ 将来

Supabase
```

V4に存在するデータのうち、

- 正しいと判断できるデータ
- 安定したID
- 英単語
- 意味
- 例文
- 発音情報

などをV5へ移す。

確認できないデータを推測して補完しない。

---



# 26. 今後の開発方針

V5 Spreadsheet完成後は、次の順序で進める。

1. Spreadsheetのカラム構造を確定
2. 実データを投入
3. AI/APIによるデータ生成方法を整備
4. データ検査処理を作成
5. Supabase側スキーマと対応付け
6. Spreadsheet → Supabase変換処理を作成
7. iOSアプリから読み取る
8. コンセプト・画像・音声切替UIへ接続

Spreadsheetは「教材を作る場所」。

Supabaseは「アプリへ届ける場所」。

アプリは「ユーザーが教材を体験する場所」。

この役割分担を基本とする。