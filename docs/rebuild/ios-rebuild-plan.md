# iOS Rebuild Plan

## Core Direction

```text
iOS中心に作り直す。
SwiftUI + Supabaseで、イラスト付き英単語帳を小さく完成させる。
```

## Keep

```text
- Supabase DB / Storage
- words / word_meanings / example_contents
- decks / deck_words
- user_learning_progress
- 生成済みの単語・例文・イラスト
- 要件定義ドキュメント
```

## Freeze

```text
- Flutter UI
- Next.js Web UI
- Flutter生成のiOS/Android/macOS等
- 仮ウィジェット
- 仮統計
- デザインカスタマイズ
- 高度なSRS/FSRS
```

## MVP

```text
ログインして、デッキを選び、
イラスト付き単語カードを学習し、
わかる/わからないをSupabaseに保存する。
```

## First Screens

```text
1. AuthView
2. DeckListView
3. StudySessionView
4. StudyCardView
```

## First Services

```text
AuthService
DeckService
StudyService
SupabaseClientProvider
```

## Do Not Build Yet

```text
- 課金
- 通知
- ゲスト学習
- プロフィール
- 設定画面
- 詳細統計
- 管理画面
- Web版
```

## Next Step

```text
SwiftUI新規プロジェクトを作る前に、
iOSが使うSupabaseクエリを5本に固定する。
```
