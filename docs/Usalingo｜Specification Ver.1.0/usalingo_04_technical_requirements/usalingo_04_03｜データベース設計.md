## ***【 usalingo_04_03｜データベース設計 】***

*命名規則やセキュリティポリシーといった設計原則から、具体的なテーブル定義、インデックス設計に至るまで、アプリケーションのデータを永続化するための論理的・物理的構造の全てを定義する。*

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

### ✦ DB オブジェクト命名規則

---

| 対象 | 命名規則 | 具体例 |
| --- | --- | --- |
| **基本** | 半角英小文字のスネークケース (`snake_case`) | `user_learning_progress` |
| **テーブル** | 複数形 | `users`, `words` |
| **カラム** | 単数形 | `email`, `word_text` |
| **主キー (PK)** | `id` | `id` |
| **外部キー (FK)** | `[参照先テーブル単数形]_id` | `user_id`, `word_id` |
| **タイムスタンプ** | `created_at` / `updated_at` | `created_at` |
| **真偽値** | `is_[状態]` プレフィックス | `is_public` |

---

### ✦ インデックス設計

*データベースのクエリパフォーマンスを維持し、アプリケーションのスケーラビリティを確保するために、主要なテーブルにインデックスを設定する。インデックスは、データの検索速度を大幅に向上させるための「索引」として機能する。*

---

| テーブル名 | インデックス名 | 対象カラム | 目的・理由 |
| --- | --- | --- | --- |
| **user_profiles** | `idx_user_profiles_on_user_id` | `user_id` | ユーザー情報取得時の `JOIN` 処理を高速化します。（FK） |
| **user_settings** | `idx_user_settings_on_user_id` | `user_id` | ユーザー設定取得時の `JOIN` 処理を高速化します。（FK） |
| **user_block_layouts** | `idx_layouts_on_user_id` | `user_id` | 特定ユーザーのブロックレイアウトを高速に検索します。 |
| **word_meanings** | `idx_meanings_on_word_id` | `word_id` | 特定の単語に紐づく意味一覧を高速に検索します。 |
| **example_contents** | `idx_examples_on_meaning_id` | `meaning_id` | 特定の意味に紐づく例文一覧を高速に検索します。 |
| **deck_words** | `idx_deck_words_on_deck_id` | `deck_id` | 特定のデッキに含まれる単語リストを高速に検索します。 |
| **deck_words** | `idx_deck_words_on_word_id` | `word_id` | 特定の単語がどのデッキに含まれるかを高速に検索します。 |
| **user_learning_progress** | `idx_progress_on_user_and_meaning` | `(user_id, meaning_id)` | 特定ユーザーの**特定の意味**に対する学習進捗を高速に取得・更新します。 |
| **user_learning_progress** | `idx_progress_on_user_and_next_review` | `(user_id, next_review_date)` | **【最重要】** 「特定のユーザーの、今日復習すべきカード」を検索する際のパフォーマンスを劇的に改善します。 |

---

### ✦ セキュリティ方針（Row Level Security）

*アクセスは原則として全て拒否し、これから定義するポリシーで許可された操作のみを可能とします。これにより、意図しないデータ漏洩のリスクを最小限に抑えます。*

---

### ● **ポリシー定義**

- **公開データ (Public Data):**
    - **対象テーブル:** `words`, `word_meanings`, `example_contents`, `decks`, `deck_words`, `card_templates`
    - **ポリシー:** **全てのユーザー（非認証ユーザーを含む）が読み取り (`SELECT`) 可能**です。書き込み（`INSERT`, `UPDATE`, `DELETE`）は全てのユーザーに対して不可とします。
- **所有権に基づくデータ (Ownership-based Data):**
    - **対象テーブル:** `user_profiles`, `user_settings`, `user_block_layouts`, `user_learning_progress`, `leitner_progress`, `sm2_progress`
    - **ポリシー:** **ユーザーは、自身の `user_id` に紐づくデータのみ、全ての操作（`SELECT`, `INSERT`, `UPDATE`, `DELETE`）が可能**です。
    - **実装:** 各テーブルに `auth.uid() = user_id` が真となる行にしかアクセスできないポリシーを設定します。
- **認証ユーザー共通データ (Authenticated User Data):**
    - **対象テーブル:** `users`
    - **ポリシー:** **認証済みのユーザーは、自身のユーザー情報のみ読み取り可能**です。他のユーザーの情報は一切読み取れません。

---

### ✦ テーブル定義（🔻 第3正規形）

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

*単語、例文、イラスト、学習デッキといったアプリケーションの学習コンテンツそのものを定義・管理するマスターテーブル群です。スプレッドシートの「一語一義」思想をデータベースとして最適な形に正規化し、データの整合性と拡張性を担保します。*

```yaml
# ===============================================
#  Tier 1: Words (親)
# ===============================================
# -----------------------------------------------
# Table: words
# -----------------------------------------------
- table: words
  description: "全ての英単語の「綴り」のみをユニークに管理する、最も基本的なマスターテーブル。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "単語の一意なID。データベースによる自動採番。"
      constraints: "not_nullable"
    - name: word_text
      type: TEXT (UNIQUE)
      description: "英単語の文字列。重複しない。"
      constraints: "not_nullable"

# ===============================================
#  Tier 2: Meanings (子)
# ===============================================
# -----------------------------------------------
# Table: word_meanings
# -----------------------------------------------
- table: word_meanings
  description: "単語が持つ一つ一つの意味を独立して管理する、コンテンツの中核テーブル。品詞や発音、語源など、意味に依存する詳細情報を格納する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "各意味の一意なID。データベースによる自動採番。"
      constraints: "not_nullable"
    - name: word_id
      type: INT (Foreign Key to words.id)
      description: "関連する親単語のID (words.id)。"
      constraints: "not_nullable"
    - name: priority
      type: INT
      description: "多義語の場合の意味の優先順位。数値が小さいほど主要な意味。"
      constraints: "not_nullable, default: 1"
    - name: part_of_speech_en
      type: TEXT
      description: "この意味に対応する品詞（英語表記）。"
      constraints: "not_nullable"
    - name: part_of_speech_jp
      type: TEXT
      description: "この意味に対応する品詞（日本語表記）。"
      constraints: "nullable"
    - name: definition_jp
      type: TEXT
      description: "単語の意味の日本語訳。"
      constraints: "not_nullable"
    - name: cefr_level
      type: TEXT
      description: "CEFR基準の難易度。"
      constraints: "nullable"
    - name: etymology
      type: TEXT
      description: "語源やコアミーニングの解説。"
      constraints: "nullable"
    - name: synonyms
      type: TEXT[]
      description: "この意味における類義語のリスト（配列）。"
      constraints: "nullable"
    - name: antonyms
      type: TEXT[]
      description: "この意味における対義語のリスト（配列）。"
      constraints: "nullable"
    - name: pronunciation_ipa
      type: TEXT
      description: "IPA形式の発音記号。"
      constraints: "nullable"
    # ➕追加：発音記号（カナ表記）
    - name: pronunciation_kana
      type: TEXT
      description: "カタカナによる発音の目安。"
      constraints: "nullable"
    # ➕追加：発音記号（CMU）
    - name: pronunciation_cmu
      type: TEXT
      description: "CMUdict形式の発音記号。"
      constraints: "nullable"
    - name: audio_filename
      type: TEXT
      description: "この意味（品詞）に対応する単語音声のファイル名。"
      constraints: "nullable"
    - name: audio_asset_path
      type: TEXT
      description: "紐付け処理後に確定した、単語音声のストレージ内パス。"
      constraints: "nullable"
    # ➕追加：活用形 (JSONB)
    - name: inflections
      type: JSONB
      description: "動詞の時制変化や名詞の複数形など、活用情報を格納する。"
      constraints: "nullable"
    # ➕追加：派生語 (JSONB)
    - name: derivatives
      type: JSONB
      description: "関連する派生語（品詞、意味）のリストを格納する。"
      constraints: "nullable"
    # ➕追加：コロケーション (JSONB)
    - name: collocations
      type: JSONB
      description: "自然な単語の組み合わせ（連語）をカテゴリ別に格納する。"
      constraints: "nullable"
    # ➕追加：フレーズ／慣用句 (JSONB)
    - name: related_phrases
      type: JSONB
      description: "単語を含む定型句や慣用句を格納する。（旧idiomから改名）"
      constraints: "nullable"

# ===============================================
#  Tier 3: Examples (孫)
# ===============================================
# -----------------------------------------------
# Table: example_contents
# -----------------------------------------------
- table: example_contents
  description: "一つの意味に対して、テーマ（シンプル、ツンデレ等）ごとに存在する例文、イラスト、音声を管理する。"
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
    - name: sentence_jp
      type: TEXT
      description: "例文の日本語訳。"
      constraints: "not_nullable"
    - name: illustration_filename
      type: TEXT
      description: "例文イラスト画像のファイル名。"
      constraints: "nullable"
    - name: illustration_asset_path
      type: TEXT
      description: "紐付け処理後に確定した、イラスト画像のストレージ内パス。"
      constraints: "nullable"
    - name: audio_filename
      type: TEXT
      description: "例文読み上げ音声のファイル名。"
      constraints: "nullable"
    - name: audio_asset_path
      type: TEXT
      description: "紐付け処理後に確定した、例文音声のストレージ内パス。"
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
  description: "どのデッキにどの単語が含まれるか、多対多の関係を定義する中間テーブル。"
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

### ✦ アセット紐付け仕様

*本仕様は、データベース（`word_meanings`, `example_contents`）に記録された**ファイル名**と、Supabase Storageに格納された**メディアアセット**（画像、音声）を関連付ける、サーバーサイドのプロセスを定義する。既存のStorageバケットを活用し、データベーストリガーによる自動紐付けとEdge Functionによる手動処理の両方に対応する。*

---

### **1. 構成要素**

- **データベース:** `word_meanings` テーブル, `example_contents` テーブル
- **ストレージ:** Supabase Storage（`content-images`, `content-audio`バケット）
- **バックエンド:** データベーストリガー + Supabase Edge Functions

---

### **2. 仕様詳細**

### **2.1. データベーススキーマ**

アセットとの関連付けを管理するため、対象テーブルには以下のカラムが定義されている。

- **`asset_path` カラム**
    - **データ型:** `text`
    - **デフォルト値:** `NULL`
    - **説明:** Storageバケット内アセットへのパスが格納される（例：`content-images/sample_banana.webp`）。このカラムが`NULL`であるレコードは「未処理」と見なされる。
    - **パス形式:** `{bucket_name}/{file_name}` の形式で記録される
- **`illustration_filename`, `audio_filename` カラム**
    - **役割:** 処理のキーとなる**元ファイル名**（例：`sample_banana.webp`）を保持する。このカラムの値は、アセット紐付けプロセスによって変更されない。
    - **用途:** データベーストリガーとEdge Functionが参照するファイル名のソース

### **2.2. Storageバケット**

アセットの管理は、役割の異なる2つのバケットによって行われる。

- **`content-images` バケット**
    - **アクセスレベル:** **公開 (Public)**
    - **用途:** イラスト画像ファイルの格納場所
    - **ファイル形式:** WEBP, PNG, JPEG
    - **参照方法:** クライアントアプリケーションは、このバケットのアセットを直接参照する
- **`content-audio` バケット**
    - **アクセスレベル:** **公開 (Public)**
    - **用途:** 音声ファイルの格納場所
    - **ファイル形式:** MP3, WAV
    - **参照方法:** クライアントアプリケーションは、このバケットのアセットを直接参照する

### **2.3. 自動紐付け処理機能**

データベースとストレージを連携させる処理は、**データベーストリガー**と**Supabase Edge Function**の2つの方法で実行される。

#### **2.3.1. 自動処理（データベーストリガー）**

- **実行タイミング:** レコードの挿入・更新時
- **処理対象テーブル:**
    - `word_meanings`: `audio_filename`カラムの変更時
    - `example_contents`: `illustration_filename`, `audio_filename`カラムの変更時
- **処理内容（命名規則適用）:**
    - `word_meanings`テーブル: `audio_filename`が設定された際、自動的に`audio_asset_path`に`content-audio/word/{id_range}/{word_id}_{meaning_id}.mp3`を設定
    - `example_contents`テーブル: `illustration_filename`が設定された際、自動的に`illustration_asset_path`に`content-images/{theme}/{id_range}/{example_id}.webp`を設定
    - `example_contents`テーブル: `audio_filename`が設定された際、自動的に`audio_asset_path`に`content-audio/example/{theme}/{id_range}/{example_id}.mp3`を設定
- **利点:** リアルタイム処理、データ整合性の自動保証、命名規則の統一

#### **2.3.2. 手動処理（Edge Function）**

- **実行タイミング:** 管理者による手動呼び出し
- **処理対象:** 未処理レコード（`asset_path IS NULL`）
- **処理フロー:**
    1. `word_meanings`および`example_contents`テーブルから未処理レコードを検索
    2. 各レコードに対し、以下の処理を順次実行：
        a. `illustration_filename`等のカラムから**ファイル名**を取得
        b. 対応するStorageバケット内でファイルの存在確認
        c. ファイルが存在する場合、`asset_path`カラムを更新
- **エラーハンドリング:**
    - ファイルが存在しないレコードはスキップされる
    - 処理は停止せず、エラーログを出力して後続処理を継続
    - 処理結果（成功件数、スキップ件数、エラー詳細）を返却

---

### **3. 動作仕様**

#### **3.1. 自動紐付け**
- **トリガー条件:** データベーストリガーによる即座の紐付け
- **処理速度:** リアルタイム（ミリ秒単位）
- **データ整合性:** 自動保証
- **運用負荷:** 最小限

#### **3.2. 手動紐付け**
- **実行方法:** Edge Function経由でのバッチ処理
- **処理対象:** 未処理レコードの一括処理
- **処理速度:** バッチ処理（秒単位）
- **監視機能:** 処理結果の詳細レポート

#### **3.3. パス形式（命名規則適用）**
- **標準形式:** `{bucket_name}/{theme}/{id_range}/{file_name}`
- **命名規則:**
    - 単語音声: `content-audio/word/{id_range}/{word_id}_{meaning_id}.mp3`
    - 例文音声: `content-audio/example/{theme}/{id_range}/{example_id}.mp3`
    - 例文イラスト: `content-images/{theme}/{id_range}/{example_id}.webp`
- **フォルダ分割:** 500ファイル/フォルダ（例: 0000-0499, 0500-0999）
- **例:**
    - 単語音声: `content-audio/word/0000-0499/123_456.mp3`
    - 例文音声: `content-audio/example/シンプル/0000-0499/789.mp3`
    - 例文イラスト: `content-images/シンプル/0000-0499/789.webp`

#### **3.4. 命名規則の適用**
- **新規ファイル:** 音声ファイル生成時に命名規則に従ったファイル名を使用
- **既存ファイル:** 段階的に命名規則に合わせてリネーム
- **運用効率:** ファイル名から内容が明確に識別可能
- **保守性:** デバッグや管理が容易

---

### **4. 運用・監視**

#### **4.1. 紐付け状況確認**
```sql
-- アセット紐付けの状況を確認
SELECT * FROM public.check_asset_linking_status();
```

#### **4.2. 手動処理実行**
```sql
-- 未処理レコードの確認
SELECT * FROM public.manual_asset_linking();
```

#### **4.3. Edge Function呼び出し**
```bash
# アセット紐付け処理の実行
curl -X POST "https://your-project.supabase.co/functions/v1/asset-linker-v2" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```