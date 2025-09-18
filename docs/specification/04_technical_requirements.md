<aside>
<img src="/icons/wheat_gray.svg" alt="/icons/wheat_gray.svg" width="40px" />

# *【 usalingo_04_technical_requirements.md 】*

*プロダクトを「どう作るか (How to build)」を定義する。技術的な実装の設計図。*

---

## ***【 usalingo_04_01｜開発環境 & 技術スタック 】***

*開発に使用するハードウェア、ソフトウェア、クラウドサービスから、アプリケーションの根幹を成す主要なライブラリまで、本プロジェクトを構成する全ての技術要素を定義する。*

---

### **● ハードウェア環境**

| 開発マシン | MacBook Air (15-inch, M2, 2023)
**チップ**: Apple M2
**メモリ**: 16 GB
**OS**: macOS Sequoia 15.6 |
| --- | --- |
| テスト用実機 | iPhone 12 (64GB) |

---

### **● ソフトウェア環境**

https://github.com/uiui-1028/usalingo_app_flutter

| IDE | Cursur AI Editer (VS Codeベース) |
| --- | --- |
| 言語／フレーム | Flutter (Dart) |
| AIエージェント | Claude Code, Gemini CLI |
| バージョン管理 | Git / GitHub |
| CI／CD | GitHub Actions |
| デザイン | Figma, Canva, iconComposer, ibisPaint |
| プロジェクト管理 | Notion, Gemini, Claude, Cursur, GoogleWorkspace |

---

### **● クラウド環境**

| BaaS | Supabase |
| --- | --- |
| データベース | Supabase Database (PostgreSQL) |
| 認証 | Supabase Auth |
| ストレージ | Supabase Storage (画像・音声) |
| アセット調達 | LottieFiles Marketplace |

---

### **● Flutter ライブラリ／パッケージング**

| 領域 | ライブラリ | 役割・責務 |
| --- | --- | --- |
| **状態管理 & DI** | **flutter_riverpod** | UIとビジネスロジックを分離し、アプリケーション全体の状態（データ）を管理する。各機能が必要とする部品（Repository, Usecaseなど）の供給も担う、`usalingo`の心臓部。 |
| **画面遷移** | **go_router** | URLベースで画面間の移動を宣言的に管理する。Web版への展開やディープリンク実装の基盤となる、アプリケーションの神経系。 |
| **ローカルDB** | **drift** | 忘却曲線アルゴリズムの進捗データなど、オフライン環境で利用する構造化データを型安全に管理する。SQLiteのパワーを最大限に引き出すためのデータ永続化層。 |
| **バックエンド連携** | **supabase_flutter** | BaaSであるSupabaseとの認証、DB同期、ストレージ操作など、サーバーとのあらゆる通信を担う。 |
| **UIアニメーション** | **lottie** | マイクロリワードやローディング画面など、ユーザー体験を豊かにする高品質なアニメーションを再生する。 |

---

## ***【 usalingo_04_03｜データベース設計 】***

*命名規則やセキュリティポリシーといった設計原則から、具体的なテーブル定義、インデックス設計に至るまで、アプリケーションのデータを永続化するための論理的・物理的構造の全てを定義する。*

---

### ✦ 設計原則

---

### ● **命名規則**

- **基本:** 半角英小文字のスネークケース (`snake_case`) のみを使用する。日本語、スペース、その他の特殊文字は使用しない。これにより、URLエンコーディングやクエリでの問題を回避する。
- **テーブル:** 複数のデータを格納するため、**複数形** (`users`, `words`, `user_settings`) を使用する。
- **カラム:** 単一の属性を表すため、**単数形** (`email`, `word_text`, `created_at`) を使用する。
- **主キー (PK):** カラム名を `id` とする。
- **外部キー (FK):** `[参照先テーブルの単数形]_id` という形式（例: `user_id`, `word_id`）を採用する。
- **タイムスタンプ:** 作成日時を `created_at`、更新日時を `updated_at` とする。
- **真偽値:** `is_` プレフィックスを使用する（例: `is_public`, `is_completed`）。

### ● **アセット管理方針**

- **単一マスターイメージの原則:** ストレージには高解像度のオリジナル画像を1つだけ保存する。
- **動的変換の活用:** 画像の配信には、Supabaseの**「Storage Image Transformation」**機能を全面的に活用する。URLのクエリパラメータ（例: `?transform=width=200`）で、表示箇所に応じた最適なサイズの画像を動的に生成・配信する。これにより、開発効率とパフォーマンスを最大化する。
- **ファイル命名:** `[単語テキスト]_[タイプ].[拡張子]` (例: `apple_illustration.webp`) の形式で、内容が推測できるファイル名とする。

---

### ✦ インデックス設計

*データベースのクエリパフォーマンスを維持し、アプリケーションのスケーラビリティを確保するために、主要なテーブルにインデックスを設定する。インデックスは、データの検索速度を大幅に向上させるための「索引」として機能する。*

---

| テーブル名 | インデックス名 | 対象カラム | 目的・理由 |
| --- | --- | --- | --- |
| **user_profiles** | `idx_user_profiles_on_user_id` | `user_id` | ユーザー情報取得時の `JOIN` 処理を高速化するため。（PKだが明示） |
| **user_settings** | `idx_user_settings_on_user_id` | `user_id` | ユーザー設定取得時の `JOIN` 処理を高速化するため。（PKだが明示） |
| **user_block_layouts** | `idx_layouts_on_user_id` | `user_id` | 特定ユーザーのブロックレイアウトを高速に検索するため。 |
| **example_contents** | `idx_examples_on_word_id` | `word_id` | 特定の単語に紐づく例文を高速に検索するため。 |
| **deck_words** | `idx_deck_words_on_deck_id` | `deck_id` | 特定のデッキに含まれる単語リストを高速に検索するため。 |
| **deck_words** | `idx_deck_words_on_word_id` | `word_id` | 特定の単語がどのデッキに含まれるかを高速に検索するため。 |
| **user_learning_progress** | `idx_progress_on_user_and_word` | `(user_id, meaning_id)` | 特定ユーザーの**特定意味**に対する学習進捗を高速に取得・更新するため。 |
| **user_learning_progress** | `idx_progress_on_user_and_next_review` | `(user_id, next_review_date)` | **最重要インデックスの一つ。**「特定のユーザーの、今日復習すべきカード」を検索する際のパフォーマンスを劇的に改善するため。 |

---

### ✦ セキュリティ方針（Row Level Security）

*アクセスは原則として全て拒否し、これから定義するポリシーで許可された操作のみを可能とします。これにより、意図しないデータ漏洩のリスクを最小限に抑えます。*

---

### ● **ポリシー定義**

- **公開データ (Public Data):**
    - **対象テーブル:** `words`, `example_contents`, `decks`
    - **ポリシー:** **全てのユーザー（非認証ユーザーを含む）が読み取り (`SELECT`) 可能。** 書き込み（`INSERT`, `UPDATE`, `DELETE`）は全てのユーザーに対して不可とする。
- **認証ユーザー共通データ (Authenticated User Data):**
    - **対象テーブル:** `users`
    - **ポリシー:** **認証済みのユーザーは、自身のユーザー情報のみ読み取り可能。** 他のユーザーの情報は読み取れない。
- **所有権に基づくデータ (Ownership-based Data):**
    - **対象テーブル:** `user_profiles`, `user_settings`, `user_learning_progress`, `user_block_layouts`
    - **ポリシー:** **ユーザーは、自身の `user_id` に紐づくデータのみ、全ての操作（`SELECT`, `INSERT`, `UPDATE`, `DELETE`）が可能。**
        - **具体例:** `user_profiles` テーブルを操作しようとする場合、`auth.uid() = user_id` が真となる行にしかアクセスできないようにポリシーを設定します。これはSupabase Authが提供する `auth.users` テーブルと連携することで実現します。

---

### ✦ ストレージ設計（Cloud／Local）

アプリケーションを構成するデータの種類、論理構造、物理的な保存場所を定義する。

---

### 【01】データスタイル定義

| データ種別 | 形式 | 主な用途 |
| --- | --- | --- |
| テキスト | TEXT / String | 単語、例文、UI上の文言など |
| 画像 | WEBP / PNG | 単語に紐づくイラスト、UIアイコンなど (※WEBPを優先し軽量化) |
| 音声 | MP3 | 単語・例文の読み上げ音声 |
| Lottie | JSON | UIアニメーション、マイクロインタラクション、学習完了時のリワードなど |

---

### 【02】データベース俯瞰図 (論理構造)

| テーブル名 | 概要 | ストレージ | 主なカラム |
| --- | --- | --- | --- |
| users | ユーザーアカウント情報 | Supabase | user_id, email, created_at |
| user_learning_progress | ユーザーごとの学習進捗と忘却曲線データ | Supabase & SQLite | id, user_id, content_id, last_reviewed, next_review_date, correct_count |
| contents | 単語や例文などのコアコンテンツ（テキスト情報） | Supabase & SQLite | content_id, word, example_sentence |
| content_assets | コンテンツに紐づくアセット（画像・音声）のパスを管理 | Supabase | asset_id, content_id, asset_type, storage_path |
| chips_data | アプリ内で使用する静的なTipsなどの情報 | SQLite | chip_id, title, description |

---

### 【03】ストレージ俯瞰図 (物理構造)

| 格納データ | ストレージ名 | 概要 |
| --- | --- | --- |
| 上記 users や contents などのテーブルデータ | Supabase Database | 構造化されたメタデータ。リレーショナルな関係性を持ち、クエリで操作される。 |
| 画像ファイル (.webp), 音声ファイル (.mp3) | Supabase Storage | コンテンツに紐づくバイナリファイル。DBからはパスで参照する。 |
| chips_data テーブル | SQLite | 頻繁な更新が不要で、オフラインでも利用したい静的な構造化データ。 |
| Lottieファイル (.json), UI用画像 | App Asset Bundle | アプリに同梱する静的アセット。UIのアニメーションなど、高速な表示が求められるもの。 |

---

### 【04】ストレージの定義

```yaml
storage_positions:
  - type: "クラウドストレージ"
    service: "Supabase"
    description: "動的に変化し、かつ複数のデバイス間で同期が必要なデータに適している。ユーザーがどのデバイスからアクセスしても、同じ学習環境を提供できる。"
    use_cases:
      - "ユーザー学習データ"
      - "コンテンツマスター"

  - type: "ローカルストレージ"
    service: "SQLite"
    description: "配布後は変更の頻度が低く、オフラインでの利用が想定される静的コンテンツに適している。アプリケーションに組み込むことで、通信環境に依存しない高速なデータアクセスが可能になる。"
    use_cases:
      - "チップスデータ"
      - "Lottieファイル"
```

---

### ✦ テーブル定義（第3正規形態）

*本セクションは、usalingo アプリケーションの根幹をなす Supabase (PostgreSQL) データベースの論理設計を定義する。現在（2025/08/08-時点）の設計は、データの冗長性を適切に排除し、更新時の不整合も起きにくい、非常にクリーンな状態である。これ以上の正規化（BCNFや第4正規形など）は、このプロジェクトの規模では複雑さを増すだけでメリットはほとんどない。*

---

### ユーザー関連 (User & Profile)

*ユーザーのアカウント情報、UI/UXのパーソナライズ設定、ブロックのレイアウトなど、**個々のユーザー体験の核となる情報**を管理するテーブル群です。*

```yaml
# -----------------------------------------------
# Table: users (Supabase Authと同期)
# -----------------------------------------------
- table: users
  description: "Supabaseの認証機能と1対1で対応する、ユーザーの基本認証情報。このテーブルへの直接的な書き込みはAuth経由で行われる。"
  columns:
    - name: id
      type: UUID (Primary Key)
      description: "Supabase Authによって自動的に割り当てられる、ユーザーの一意なID。"
      constraints: "not_nullable"
    - name: email
      type: TEXT
      description: "ユーザーのメールアドレス。"
      constraints: "not_nullable"
    - name: created_at
      type: TIMESTAMPTZ
      description: "アカウントの作成日時。"
      constraints: "not_nullable, default: now()"

# -----------------------------------------------
# Table: user_profiles
# -----------------------------------------------
- table: user_profiles
  description: "ユーザーのプランやニックネームなど、付加的なプロフィール情報を格納する。"
  columns:
    - name: user_id
      type: UUID (Primary Key, Foreign Key to users.id)
      description: "ユーザーID。usersテーブルとのリレーションを確立する。"
      constraints: "not_nullable"
    - name: plan
      type: TEXT
      description: "ユーザーの現在のプラン ('free' or 'pro') 。"
      constraints: "not_nullable, default: 'free'"
    - name: nickname
      type: TEXT
      description: "アプリ内で表示されるユーザーの名前。"
      constraints: "nullable"

# -----------------------------------------------
# Table: user_settings
# -----------------------------------------------
- table: user_settings
  description: "UIテーマ、フォント、音声など、ユーザーがカスタマイズしたアプリの表示・挙動設定を管理する。"
  columns:
    - name: user_id
      type: UUID (Primary Key, Foreign Key to users.id)
      description: "ユーザーID。"
      constraints: "not_nullable"
    - name: design_style
      type: TEXT
      description: "UIの基本スタイル (例: 'flat_design', 'neumorphism') 。"
      constraints: "not_nullable, default: 'flat_design'"
    - name: color_mode
      type: TEXT
      description: "カラーモード ('light', 'dark', 'system') 。"
      constraints: "not_nullable, default: 'system'"
    - name: accent_color
      type: TEXT
      description: "アクセントカラーのHEXコード。"
      constraints: "not_nullable, default: '#FF5D97'"
    - name: font_family
      type: TEXT
      description: "アプリ全体のフォントファミリー名。"
      constraints: "not_nullable, default: 'system_default'"
    - name: card_interaction_mode
      type: TEXT
      description: "解答インタラクション ('punch' or 'flip') 。"
      constraints: "not_nullable, default: 'punch'"
    - name: tts_config
      type: JSONB
      description: "Text-to-Speechの音声（性別、速度など）に関する設定を格納する。"
      constraints: "nullable"
    - name: selected_card_template_id
      type: INT (Foreign Key to card_templates.id)
      description: "ユーザーが選択したカードテンプレートのID。"
      constraints: "not_nullable, default: 1"
    - name: algorithm_settings
      type: JSONB
      description: "ユーザーがカスタマイズした忘却曲線アルゴリズムのパラメータを格納する。（例：{'new_cards_per_day': 15, 'interval_modifier': 1.2}）"
      constraints: "nullable"
    - name: selected_algorithm
      type: TEXT
      description: "ユーザーが選択した忘却曲線アルゴリズム ('leitner', 'sm2'など)。"
      constraints: "not_nullable, default: 'sm2'"

# -----------------------------------------------
# Table: user_block_layouts
# -----------------------------------------------
- table: user_block_layouts
  description: "ユーザーが「学習」「プロフィール」の各タブに配置したブロックのレイアウト情報を管理する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "レイアウト情報の一意なID。"
      constraints: "not_nullable"
    - name: user_id
      type: UUID (Foreign Key to users.id)
      description: "このレイアウトを所有するユーザーID。"
      constraints: "not_nullable"
    - name: tab_name
      type: TEXT
      description: "ブロックが配置されているタブ名 ('learning' or 'profile') 。"
      constraints: "not_nullable"
    - name: block_type
      type: TEXT
      description: "ブロックの種類 (例: 'deck', 'streak', 'heatmap') 。"
      constraints: "not_nullable"
    - name: related_id
      type: INT
      description: "ウィジェットが特定のマスターデータを参照する場合、そのIDを格納する (例: 学習デッキのID)。'streak'や'heatmap'のように、特定のマスターデータに依存しないウィジェットの場合はNULLとなる。"
      constraints: "nullable"
    - name: display_order
      type: INT
      description: "タブ内での表示順序。"
      constraints: "not_nullable"
    - name: settings
      type: JSONB
      description: "ブロック固有の設定（例：学習デッキの出題範囲やスタイル）を格納する。"
      constraints: "nullable"
```

---

### コンテンツ関連 (Content & Deck)

*単語、例文、イラスト、学習デッキといった**アプリケーションの学習コンテンツそのもの**を定義・管理するマスターテーブル群です。*

```yaml
# -----------------------------------------------
# Table: words
# -----------------------------------------------
- table: words
  description: "全ての英単語の基本情報を格納するマスターテーブル。「ワードファミリー」の基幹となる単語を登録する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "単語の一意なID。"
      constraints: "not_nullable"
    - name: rank
      type: INTEGER
      description: "単語の出現頻度ランク。数値が小さいほど高頻度（基礎的）な単語であることを示す。"
      constraints: "nullable"
    - name: word_text
      type: TEXT (UNIQUE)
      description: "英単語の文字列。"
      constraints: "not_nullable"
    - name: etymology
      type: TEXT
      description: "語源の解説。"
      constraints: "nullable"
    - name: phonetic_symbol
      type: TEXT
      description: "国際音声記号（IPA）による発音記号。"
      constraints: "nullable"
    - name: audio_urls
      type: JSONB
      description: "単語音声のURLをアクセント・性別ごとに格納する。（例: {'us_female': 'path/to/audio.mp3'}）"
      constraints: "nullable"

# -----------------------------------------------
# Table: word_meanings
# -----------------------------------------------
- table: word_meanings
  description: "単語が持つ一つ一つの意味を独立して管理するテーブル。多義語に対応する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "意味の一意なID。"
      constraints: "not_nullable"
    - name: word_id
      type: INT (Foreign Key to words.id)
      description: "関連する単語のID。"
      constraints: "not_nullable"
    - name: priority
      type: INT
      description: "意味の優先順位。数値が小さいほど主要な意味であることを示す。"
      constraints: "not_nullable, default: 1"
    - name: part_of_speech
      type: TEXT
      description: "この意味に対応する品詞。"
      constraints: "not_nullable"
    - name: definition
      type: TEXT
      description: "単語の意味の日本語訳。"
      constraints: "not_nullable"
    - name: synonyms
      type: TEXT[]
      description: "この意味における類義語のリスト。"
      constraints: "nullable"
    - name: antonyms
      type: TEXT[]
      description: "この意味における対義語のリスト。"
      constraints: "nullable"

# -----------------------------------------------
# Table: example_contents
# -----------------------------------------------
- table: example_contents
  description: "一つの単語に対して、テーマ（シンプル、ツンデレ等）ごとに存在する例文、イラスト、音声を管理する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "コンテンツセットの一意なID。"
      constraints: "not_nullable"
    - name: meaning_id
      type: INT (Foreign Key to word_meanings.id)
      description: "この例文が対応する、単語の具体的な意味のID。"
      constraints: "not_nullable"
    - name: theme
      type: TEXT
      description: "コンテンツのテーマ ('simple', 'tsundere', 'animal'など) 。"
      constraints: "not_nullable, default: 'simple'"
    - name: sentence_en
      type: TEXT
      description: "英語の例文。"
      constraints: "not_nullable"
    - name: sentence_ja
      type: TEXT
      description: "例文の日本語訳。"
      constraints: "not_nullable"
    - name: illustration_url
      type: TEXT
      description: "例文イラスト画像のURL (Supabase Storage) 。"
      constraints: "nullable"
    - name: audio_url
      type: TEXT
      description: "例文読み上げ音声のURL (Supabase Storage) 。"
      constraints: "nullable"

# -----------------------------------------------
# Table: decks
# -----------------------------------------------
- table: decks
  description: "学習デッキのマスターデータを定義する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "デッキの一意なID。"
      constraints: "not_nullable"
    - name: deck_name
      type: TEXT (UNIQUE)
      description: "デッキの名称 (例: 'NGSL - 基礎単語') 。"
      constraints: "not_nullable"
    - name: description
      type: TEXT
      description: "デッキの内容に関する詳細な説明。"
      constraints: "nullable"
    - name: source_list_name
      type: TEXT
      description: "参照元の単語リスト名 (例: 'NGSL', 'TSL') 。"
      constraints: "nullable"
    - name: license
      type: TEXT
      description: "コンテンツのライセンス情報 (例: 'CC BY-SA 4.0') 。"
      constraints: "nullable"

# -----------------------------------------------
# Table: deck_words
# -----------------------------------------------
- table: deck_words
  description: "どのデッキにどの単語が含まれるか、多対多の関係を定義する中間テーブル。同じ単語を重複して生成する必要はない。"
  columns:
    - name: deck_id
      type: INT (Primary Key, Foreign Key to decks.id)
      description: "デッキID。"
      constraints: "not_nullable"
    - name: word_id
      type: INT (Primary Key, Foreign Key to words.id)
      description: "単語ID。"
      constraints: "not_nullable"

# -----------------------------------------------
# Table: card_templates
# -----------------------------------------------
- table: card_templates
  description: "カードのレイアウトや表示項目の組み合わせを「テンプレート」として管理するマスターテーブル。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "テンプレートの一意なID。"
      constraints: "not_nullable"
    - name: template_name
      type: TEXT (UNIQUE)
      description: "テンプレートの名称（例：「シンプル重視」「情報たっぷり」「イラストメイン」）。"
      constraints: "not_nullable"
    - name: surface_a_items
      type: TEXT[]
      description: "カードの表面に表示する項目を配列で定義（例：['word', 'illustration']）。"
      constraints: "not_nullable"
    - name: surface_b_items
      type: TEXT[]
      description: "カードの裏面に表示する項目を配列で定義（例：['definition', 'sentence_en', 'synonyms']）。"
      constraints: "not_nullable"
```

---

### 学習進捗関連 (Learning Progress)

*どのユーザーが、どの単語を、いつ、どのレベルまで習得したか。**忘却曲線アルゴリズムの根幹をなし、学習の継続性を支える**パーソナルな進捗データを記録するテーブル群です。*

```yaml
# -----------------------------------------------
# Table: user_learning_progress
# -----------------------------------------------
- table: user_learning_progress
  description: "ユーザーごとの、単語の意味単位での共通学習進捗を管理する。アルゴリズム固有の情報は含まない。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "学習進捗レコードの一意なID。"
      constraints: "not_nullable"
    - name: user_id
      type: UUID (Foreign Key to users.id)
      description: "ユーザーID。"
      constraints: "not_nullable"
    - name: meaning_id
      type: INT (Foreign Key to word_meanings.id)
      description: "学習対象の単語の意味ID。"
      constraints: "not_nullable"
    - name: status
      type: TEXT
      description: "学習ステータス ('new', 'learning', 'mastered') 。"
      constraints: "not_nullable, default: 'new'"
    - name: last_reviewed_at
      type: TIMESTAMPTZ
      description: "最後にこの単語を復習した日時。"
      constraints: "nullable"
    - name: next_review_date
      type: TIMESTAMPTZ
      description: "アルゴリズムによって算出された、次回復習推奨日時。クエリのパフォーマンス向上のため、この共通テーブルに保持する。"
      constraints: "nullable"
    - name: created_at
      type: TIMESTAMPTZ
      description: "レコード作成日時"
      constraints: "not_nullable, default: now()"
    - name: updated_at
      type: TIMESTAMPTZ
      description: "レコード更新日時"
      constraints: "not_nullable, default: now()"
  constraints: "UNIQUE(user_id, meaning_id)"

# -----------------------------------------------
# Table: leitner_progress
# -----------------------------------------------
- table: leitner_progress
  description: "リートナー方式の進捗パラメータを管理する。"
  columns:
    - name: progress_id
      type: INT (Primary Key, Foreign Key to user_learning_progress.id)
      description: "対応する共通進捗レコードのID。"
      constraints: "not_nullable"
    - name: srs_level
      type: INT
      description: "リートナー方式における現在のレベル（1〜5）。"
      constraints: "not_nullable, default: 1"

# -----------------------------------------------
# Table: sm2_progress
# -----------------------------------------------
- table: sm2_progress
  description: "SM-2アルゴリズムの進捗パラメータを管理する。"
  columns:
    - name: progress_id
      type: INT (Primary Key, Foreign Key to user_learning_progress.id)
      description: "対応する共通進捗レコードのID。"
      constraints: "not_nullable"
    - name: easiness_factor
      type: REAL
      description: "SM-2アルゴリズムにおける易しさ係数（E-Factor）。"
      constraints: "not_nullable, default: 2.5"
    - name: repetitions
      type: INT
      description: "SM-2アルゴリズムにおける連続正解回数。"
      constraints: "not_nullable, default: 0"
    - name: interval_days
      type: INT
      description: "SM-2アルゴリズムにおける前回の復習間隔。"
      constraints: "not_nullable, default: 0"
```

---

### ✦ **マイグレーション**

*データベーススキーマの変更を安全かつ再現可能な形で管理・適用するための標準的な開発プロセス。全てのスキーマ変更はこのワークフローに従い、Gitでバージョン管理される。*

```yaml
--------------------------------
WORKFROW: "データベースマイグレーション"
name: データベースマイグレーション (Database Migration)
description: データベースの構造変更をコードとして管理し、開発環境から本番環境へ安全に適用するための標準手順。
tool: Supabase CLI
workflow:
--------------------------------
- step: 1. 変更ファイルの作成 (Creation)
details: 開発者のローカル環境で supabase migration new <migration_name> コマンドを実行し、スキーマ変更内容を記述するための新しいSQLファイルを作成する。
--------------------------------
- step: 2. スキーマ変更の記述 (Implementation)
details: 作成されたSQLファイルに、CREATE TABLE, ALTER TABLE, CREATE INDEX などのSQL文を記述する。
--------------------------------
- step: 3. 開発環境でのテスト (Testing)
details: 開発環境のデータベースに対してマイグレーションを適用 (supabase db push等) し、意図通りにスキーマが変更され、既存機能に影響がないことを確認する。
--------------------------------
- step: 4. バージョン管理へのコミット (Commit)
details: テストが完了したマイグレーションファイルをGitにコミットし、チームにレビューを依頼する。
--------------------------------
- step: 5. 本番環境への適用 (Deployment)
details: レビューで承認された後、CI/CDパイプラインまたは手動で supabase migration up コマンドを実行し、本番環境のデータベースに一連の変更を適用する。
```

---

## ***【 usalingo_04_04｜アルゴリズム設計 】***

*忘却曲線に基づく復習スケジューリングから、ユーザーに最適なコンテンツを提示するパーソナライズ、UIテーマの動的切り替えまで、アプリケーションの知的挙動を実現する核心的なロジックを定義する。* 

---

### 【 Algorithm｜01 】忘却曲線 アルゴリズム（ リートナー方式 ）

 *MVP段階では、オフライン学習機能テストとコスト削減のため、ユーザー端末のローカルDB（SQLite）で管理する**リートナー方式**を採用する。*

---

**● データモデル（ローカルDB｜SQLite）**

| カラム名 | 型 | 説明 |
| --- | --- | --- |
| word_id | INTEGER | どの単語の進捗かを示す一意な ID |
| srs_level | INTEGER | リートナー方式のレベル（1〜5）, 数値が高いほど定着している状態を示す |
| next_review_date | TEXT | 次回復習日を YYYY-MM-DDTHH:MM:SS 形式の文字列で格納 |

---

**● アルゴリズム仕様**

```yaml
# ===============================================
# Algorithm Spec: Leitner System (MVP)
# ===============================================

# -----------------------------------------------
# 1. 復習間隔の定義 (SRS Levels)
# -----------------------------------------------
- level: 1
  interval_days: 1
  description: "「わからない」と評価されたカードが属する初期レベル"
- level: 2
  interval_days: 3
- level: 3
  interval_days: 7
- level: 4
  interval_days: 14
- level: 5
  interval_days: 30
  description: "このレベルをクリアすると「マスター済み」と見なす"

# -----------------------------------------------
# 2. ロジックフロー
# -----------------------------------------------
- event: "カードを「わかる」にスワイプ"
  action:
    - "srs_level を 1つ進める (例: level 2 -> level 3)。"
    - "進んだ先のレベルに対応する interval_days を現在日時に加算し、next_review_date を更新する"

- event: "カードを「わからない」にスワイプ"
  action:
    - "srs_level を 1 にリセットする。"
    - "レベル1の interval_days を現在日時に加算し、next_review_date を更新する"

# -----------------------------------------------
# 3. データ同期方針
# -----------------------------------------------
- primary_storage: "ユーザー端末内のローカルDB (SQLite)"
  description: "オフラインでの軽快な動作を保証する"
```

---

### 【 Algorithm｜02 】忘却曲線 アルゴリズム（ SM-2 ）

 *本来は4択でグラデーションを持って計量するところを, 2択のシンプルなUIUXで独自に再編成した、SM-2のパーソナライズ機能を一部取り入れたハイブリッド方式。*

---

**● データモデル（ローカルDB｜SQLite）**

| カラム名 | 型 | 説明 |
| --- | --- | --- |
| word_id | INTEGER | どの単語の進捗かを示す一意なID。 |
| easiness_factor | REAL | 易しさ係数（E-Factor）。初期値は2.5。 |
| repetitions | INTEGER | 連続正解回数。不正解で0にリセットされる。 |
| interval_days | INTEGER | 前回の復習間隔（日数）。 |
| next_review_date | TEXT | 次回復習日。 |

---

**● アルゴリズム仕様**

```yaml
# ===============================================
# Algorithm Spec: 2-Choice SM-2 (Hybrid)
# ===============================================

# -----------------------------------------------
# 1. ユーザー入力の定義
# -----------------------------------------------
# ユーザーの操作は「わかる」「わからない」の2択のみ。
- event: "カードを「わかる」にスワイプ"
  is_correct: true

- event: "カードを「わからない」にスワイプ"
  is_correct: false

# -----------------------------------------------
# 2. ロジックフロー
# -----------------------------------------------
#  note: 以下のロジックで使用される全ての固定値（初期値、係数など）は、まず `user_settings.algorithm_settings` 内にユーザー定義の値が存在するかを確認し、存在しない場合のみ、システムで定義されたデフォルト値を使用する。

- event: "is_correct が false の場合"
  action:
    - "repetitions を 0 にリセットする。"
    - "interval_days を 1 にリセットする。"
    - "easiness_factor を 0.2 減少させる（下限は1.3）。"

- event: "is_correct が true の場合"
  action:
    - "repetitions を 1つ進める。"
    - "easiness_factor は変更しない（または僅かに増加させる）。"
    - "repetitions の値に応じて interval_days を計算・更新する。"
    - "  - 1回目: 1日"
    - "  - 2回目: 6日"
    - "  - 3回目以降: 前回のinterval_days * easiness_factor"
    - "最後に、計算された interval_days を基に next_review_date を更新する。"

# -----------------------------------------------
# 3. データ同期方針
# -----------------------------------------------
- primary_storage: "ユーザー端末内のローカルDB (SQLite)"
- secondary_storage: "クラウドDB (Supabase)"
- sync_trigger: "定期的、または手動でのバックアップと復元。"
```

---

### 【 Algorithm｜03 】**英語力別のデータパーソナライズ方法**

*本アルゴリズムは、ユーザーがアプリを使い始めた瞬間の体験価値を最大化し、学習離脱率を低減させることを目的とする。*

---

### **✦ 基本思想**

多くのユーザーは、学習を開始する前の「選択」や「登録」といった行為に負荷を感じ、意欲を削がれてしまう。この障壁を取り除くため、アプリ初回起動時にはアカウント登録を要求せず、標準の「ウェルカムデッキ」を自動提供し、即座に学習を開始できる環境を用意する。その後、ユーザーがアカウント登録を行った際には、それまでの学習履歴を失うことなく新しいアカウントへ引き継ぐ。同時に、アンケートに基づきユーザーの目的に合った「パーソナライズドデッキ」を新しいブロックとして追加することで、気軽な体験から本格的なパーソナライズ学習へのシームレスな移行を実現する。

---

### **✦ アルゴリズム仕様**

```yaml
# ===============================================
# Algorithm Spec: Initial Content Personalization Strategy (Integrated Ver.)
# ===============================================

# -----------------------------------------------
# 1. フェーズ1：ゲスト体験（アプリ初回起動時）
# -----------------------------------------------
- event: ユーザーがアプリを初めて起動する
- action:
    - 1. ウェルカムデッキの自動配置：約300語を収録した標準のウェルカムデッキを、学習タブのブロックエリアに自動で配置する。
    - 2. ゲスト学習の開始：ユーザーはアカウント登録なしで、すぐにウェルカムデッキの学習を開始できる。学習進捗は端末のローカルDB（SQLite）に一時的に保存される。
- result: ユーザーは一切の摩擦なく、即座に学習体験を開始できる。

# -----------------------------------------------
# 2. フェーズ2：パーソナライズ（アカウント登録完了後）
# -----------------------------------------------
- event: ユーザーが新規アカウント登録を正常に完了する
- action:
------------------------------------------
    - 1. 学習履歴の継承：ローカルDBに保存されていたゲスト時の学習進捗（ウェルカムデッキの進捗）を、新しく作成されたユーザーアカウントに紐付け、Supabaseに保存する。
------------------------------------------
    - 2. オンボーディング・アンケートの実施：ユーザーに単一選択式の質問を提示し、学習目的を特定する。
    -   question_text: あなたの主な学習目的を教えてください
    -   options:
          - id: daily_conversation
            label: 日常英会話
          - id: business
            label: ビジネス英会話
          - id: toeic
            label: TOEIC / 英検対策
          - id: exam
            label: 大学受験
          - id: junior_english
            label: 中学・高校の復習
          - id: none
            label: 特に決まっていない
------------------------------------------
    - 3. 最適な学習デッキの追加：アンケートの回答（option.id）に基づき、以下のマッピングルールに従ってパーソナライズドデッキを決定し、学習タブに新しいブロックとして追加する。
    -   mapping_rules:
          - if: option.id is 'daily_conversation'
            then: deck_id: 1 (NGSL基礎単語デッキ) をブロックとして追加する
          - if: option.id is 'business'
            then: deck_id: 2 (BSLビジネス単語デッキ) をブロックとして追加する
          - if: option.id is 'toeic'
            then: deck_id: 3 (TSL TOEIC頻出単語デッキ) をブロックとして追加する
          - if: option.id is 'exam' or 'junior_english'
            then: deck_id: 4 (学術基礎単語デッキ) をブロックとして追加する
          - if: option.id is 'none'
            then: deck_id: 1 (NGSL基礎単語デッキ) をデフォルトとして追加し、さらにデッキ選択を促すUIを表示する
- result: 学習タブにはウェルカムデッキと新しいパーソナライズドデッキが別々のブロックとして共存する。ユーザーは自身の学習履歴を維持したまま、新たな目的の学習へとスムーズに移行できる。
```

---

### 【 Algorithm｜04 】動的UIテーマシステム

*本アルゴリズムは、競争優位性の一つである「適応型パーソナル空間（アダプティブ・スペース）」を実現するための技術的根幹である。中心的な思想は、UIの構造的骨格と、その視覚的表現であるデザイン思想を完全に分離することにある。これにより、UIデザインの拡張性とメンテナンス性を最大化する。*

---

### **1. テーマの契約**

全てのデザイン思想が遵守すべき統一のインターフェース、すなわち「契約」として、一つの抽象クラスを定義する。この契約には、アプリケーションのUIを構成するために必要な、全てのデザイン要素をプロパティとして網羅的に宣言する。これにより、どのデザイン思想を実装する際にも考慮すべき要素の漏れを防ぎ、アプリケーション全体の一貫性を保証する。

| カテゴリ | 属性（例） | 説明 |
| --- | --- | --- |
| **色彩** | 背景色, 基本色, アクセントカラー, テキスト色 | アプリ内で使用する全ての色を定義する。 |
| **タイポグラフィ** | 見出し/本文のフォントファミリー, サイズ, ウェイト | 役割に応じたフォントの階層を定義する。 |
| **形状** | 角丸の半径, 境界線のスタイル | コンポーネントの形状に関する規定を定義する。 |
| **エフェクト** | 陰影の付け方, ブラーの強度 | 視覚効果に関する規定を定義する。 |
| **スペーシング**  | 標準マージン, パディング | コンポーネント間の余白に関する値を定義する。 |

---

### **2. テーマの実装規約（提供側）**

「マテリアルデザイン」や「ニューモーフィズム」といった個別のデザイン思想を、原則1で定義した契約を実装する具体的なクラスとして作成する。各クラスは、契約で定められた全てのプロパティに対し、自身のデザイン思想に基づいた具体的な値を設定する必要がある。このルールにより、将来的に新しいデザイン思想を追加したい場合でも、この契約に準拠した新しいクラスファイルを追加するだけで対応が完了し、既存コードへの影響は最小限に抑えられる。

---

### **3. テーマの利用規約（参照側）**

アプリケーションのUIを構築する際、個々のブロックは特定の色やフォントサイズといった値を直接コード内に記述しません。その代わり、状態管理システムを通じて、現在ユーザーに選択されているテーマオブジェクトを一元的に受け取る。全てのブロックは、この注入されたテーマオブジェクトから「基本色」や「標準の角丸」といった値を参照して自身のスタイルを決定する。これにより、注入するテーマオブジェクトを切り替えるだけで、アプリケーション全体のルックアンドフィールを瞬時に、かつ整合性を保ったまま変更することが可能になる。

---

### 4. ワイヤーフレームテーマ｜スタイル定義

*「ワイヤーフレーム駆動開発」で用いる、UIの骨格を可視化するためのテーマ。全てのコンポーネントは、ここで定義された統一のスタイルに従う。*

```css
/* --- Wireframe Theme Specification (Comprehensive Ver.) --- */

.theme_wireframe {
  name: "ワイヤーフレームテーマ";
  description: "機能の構造とレイアウトに集中するための、装飾を排したテーマ。";
}

/* ----------------------------------
 * ◆ 基本原則 (Global Rules)
 * ---------------------------------- */

/* ▼ 色彩：意味を持たないグレースケールに統一 */
--color-background: #FFFFFF;  /* 画面背景 */
--color-surface: #F5F5F5;     /* カードやボタンなどのコンポーネント表面 */
--color-border: #CCCCCC;      /* 境界線 */
--color-text-primary: #393939;/* 主要テキスト */
--color-text-secondary: #888888;/* 補助テキスト */
--color-icon: #757575;        /* アイコン */
--color-overlay: rgba(0, 0, 0, 0.4); /* ダイアログ背後のオーバーレイ */

/* ▼ 形状：全ての角丸と境界線を統一 */
--shape-corner-radius: 4px;
--shape-border-width: 1.5px;
--shape-border-style: solid;

/* ▼ タイポグラフィ：構造を意識させる等幅フォントを採用 */
--font-family: 'Roboto Mono', monospace;

/* ----------------------------------
 * ◆ ナビゲーション (Navigation)
 * ---------------------------------- */

/* ▼ トップバー / ボトムバー */
.navigation-bar {
  background-color: var(--color-surface);
  border-bottom: var(--shape-border-width) var(--shape-border-style) var(--color-border);
  /* Note: ボトムバーの場合は border-top に適用 */
}

/* ----------------------------------
 * ◆ 基本コンポーネント (Basic Components)
 * ---------------------------------- */

/* ▼ ボタン (Button) */
.button {
  background-color: transparent;
  border: var(--shape-border-width) var(--shape-border-style) var(--color-border);
  border-radius: var(--shape-corner-radius);
  color: var(--color-text-primary);
  padding: 8px 16px;
}

/* ▼ カード (Card) */
.card {
  background-color: var(--color-surface);
  border: var(--shape-border-width) var(--shape-border-style) var(--color-border);
  border-radius: var(--shape-corner-radius);
  box-shadow: none; /* 影は使用しない */
}

/* ▼ アイコン (Icon) */
.icon {
  color: var(--color-icon);
  /* 原則として線画のアイコンセット (Outlined) を使用 */
}

/* ▼ 区切り線 (Divider) */
.divider {
  height: 1px;
  background-color: var(--color-border);
  border: none;
}

/* ----------------------------------
 * ◆ 入力コントロール (Input Controls)
 * ---------------------------------- */

/* ▼ テキスト入力フィールド (Text Field) */
.text-field {
  background-color: transparent;
  border: var(--shape-border-width) var(--shape-border-style) var(--color-border);
  border-radius: var(--shape-corner-radius);
  padding: 10px;
}

/* ▼ スイッチ (Switch) / トグル */
.switch {
  /* OFF: 薄いグレーの背景に白い円 */
  /* ON:  少し濃いグレーの背景に白い円 */
  border-radius: 16px; /* 角を完全に丸める */
}

/* ▼ チェックボックス (Checkbox) */
.checkbox {
  /* 四角い枠線。チェック時は内に黒い四角形を表示 */
  width: 20px;
  height: 20px;
  border: var(--shape-border-width) var(--shape-border-style) var(--color-border);
}

/* ▼ ドロップダウンメニュー (Dropdown) */
.dropdown {
  /* 見た目は .button と同様。右端に下向きのシェブロンアイコンを配置 */
}

/* ----------------------------------
 * ◆ フィードバック要素 (Feedback Elements)
 * ---------------------------------- */

/* ▼ ダイアログ (Dialog) / モーダル */
.dialog {
  /* 本体は .card のスタイルを適用 */
  /* 背面に --color-overlay を表示 */
}

/* ▼ スナックバー (Snackbar) / トースト */
.snackbar {
  background-color: #333333;
  color: #FFFFFF;
  border-radius: var(--shape-corner-radius);
  box-shadow: none;
}

/* ▼ チップ (Chip) / バッジ (Badge) */
.chip {
  background-color: transparent;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 4px 8px;
  font-size: 12px;
}

/* ▼ プログレスインジケーター (Progress Indicator) */
.progress-indicator {
  /* シンプルな円形（回転）または線形（進捗）インジケーター */
  /* 色は --color-text-primary を使用 */
}
```

---