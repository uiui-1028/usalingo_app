# Usalingo Ver.2.0

Usalingoは、運営が用意した英単語カードを使い、正解・不正解を答えながら復習するiPhone向け学習アプリです。
学習結果と次の復習予定は、ログインした利用者ごとにSupabaseへ保存します。

## 最初に読む順番

1. [正式な機能範囲](docs/decisions/usl-207-official-feature-scope.md)

   現在使える機能、今は説明に載せない機能、将来案を確認します。
2. [SwiftUIアプリの起動方法](apps/ios-swiftui/README.md)

   ローカル設定を用意し、Xcodeでアプリを開きます。
3. [現在の学習ルール](docs/architecture/anki-aligned-spec.md)

   カードの出し方、正解・不正解、復習予定の考え方を確認します。
4. [データの仕組み](docs/architecture/anki-data-model.md)

   単語、カード、デッキ、利用者ごとの進捗の関係を確認します。
5. [Supabaseの変更ルール](docs/supabase/README.md)

   データベースを変更するときの正本と安全な進め方を確認します。

## アプリの場所

現在のアプリは次の場所にあります。

```text
apps/ios-swiftui/
```

起動するときは、上のフォルダにある `UsalingoIOS.xcodeproj` をXcodeで開きます。必要な設定値とテスト方法は[SwiftUIアプリのREADME](apps/ios-swiftui/README.md)にあります。

## 古いFlutter資料について

ルート直下や `docs/` には、移行前のFlutterを前提にした資料が残っています。Flutter、Dart、Riverpod、`flutter run`、旧SQLite構成が書かれた資料は、現在のSwiftUIアプリの説明ではありません。

過去の設計を調べる目的以外では、`apps/ios-swiftui/` と、このページから案内する現在資料を使ってください。
