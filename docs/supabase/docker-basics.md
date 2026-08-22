# Docker入門：Usalingoの安全な実験箱

最終確認日: 2026-08-21

## Dockerとは？

Dockerは、アプリやデータベースを動かすための**小さな実験箱**です。

箱の中で失敗しても、本番のSupabaseや利用者データへ影響させず、箱を作り直して最初から試せます。

## Xcodeとの違い

| 道具 | 役割 |
| --- | --- |
| Xcode | iPhoneアプリの画面・ボタン・Swiftコードを作って試す |
| Docker | データベース・ログイン・権限・StorageをMacの中で試す |

Xcodeだけでは、データベースのmigration、RLS、GRANT、Storage policyの実動作を確認できません。

## なぜよく使われるの？

- **安全**: 本番とは別の場所で試せる。
- **同じ環境**: どのMacでも同じ実験箱を作りやすい。
- **やり直せる**: データが壊れても箱を作り直せる。
- **自動化できる**: 毎回同じ手順でテストできる。
- **片付けやすい**: 使い終わったサービスをまとめて止められる。

## よく出る言葉

| 言葉 | かんたんな意味 |
| --- | --- |
| イメージ | 実験箱の設計図 |
| コンテナ | 設計図から作った実験箱 |
| Docker Desktop | MacでDockerを動かすアプリ |
| Supabase CLI | Docker内のDB・Auth・Storageをまとめて操作する道具 |
| migration | DBの形を順番に変更する設計書 |
| seed | ローカルテスト用の見本データ |

## Usalingoでの使い方

```text
Docker Desktopを起動
        ↓
supabase start
        ↓
ローカルDB・Auth・Storageを起動
        ↓
migrationと権限をテスト
        ↓
supabase stop
```

基本の確認コマンドです。

```bash
docker version
docker system df
supabase --version
supabase start
supabase status
supabase stop
```

`docker version` では、`Client` と `Server` の両方が表示されれば、Docker本体まで動いています。

## 容量と学習コスト

- Docker DesktopとSupabaseのイメージ・データで、数GB〜10GB以上使うことがある。
- 使わないイメージやデータを残すと、使用量は増える。
- 基本操作は半日〜1日、Supabaseを含む安全な運用は数日かけて覚えればよい。
- 容量を消す操作では、ローカルDBのデータも消えることがある。削除前に対象を確認する。

## 必ず守ること

- 本番project ref、パスワード、利用者データをローカル実験へ持ち込まない。
- `service_role` や秘密鍵をiPhoneアプリへ入れない。
- `--local` と `--linked` を区別する。`--linked` は外部DBへつながる可能性がある。
- `supabase db reset` は対象DBを作り直す。実行前にローカル環境であることを確認する。
- Dockerで動いたことは、本番で動いた証明ではない。

## 現在のUsalingo環境

- Docker Desktop: **29.7.2**
- Docker Client・Server接続: **確認済み**
- Supabase CLI: **2.33.9**
- Docker導入直後の使用量: **0B**
- ローカルSupabaseの完全な再現環境: **未完成**

次はUSL-222で、基準migration、`supabase/config.toml`、テスト用seedを整えます。本番Supabaseへの接続や変更は行いません。

## ひとことで思い出す

> Dockerは、本番をこわさず、同じ状態から何度でも試せる「安全な実験箱」です。

## 公式資料

- [Docker DesktopをMacへインストールする](https://docs.docker.com/desktop/setup/install/mac-install/)
- [Supabaseのローカル開発](https://supabase.com/docs/guides/local-development)
- [Supabase CLIのローカル開発フロー](https://supabase.com/docs/guides/local-development/cli-workflows)
