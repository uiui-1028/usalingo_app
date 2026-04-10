# Usalingo Web (Next.js)

このディレクトリは、UsalingoのWeb版アプリです。  
開発フェーズは無料運用しやすく、Next.jsとの親和性が高い **Vercel** へのデプロイを前提にしています。

## ローカル起動

1. 依存関係をインストール

```bash
npm install
```

1. 環境変数を設定

```bash
cp .env.example .env.local
```

`.env.local` に以下を設定してください。

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_APP_URL`（例: `http://localhost:3000`）

1. 開発サーバー起動

```bash
npm run dev
```

## デプロイ（推奨: Vercel）

1. GitHubリポジトリをVercelに連携
1. Project Root を `apps/web` に設定
1. Environment Variables に以下を登録
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `NEXT_PUBLIC_APP_URL`（本番URL）
1. `main` へpushで自動デプロイ

## 補足

- WebはNext.jsで高速に仮説検証し、確立した仕様をモバイルへ展開する運用を想定
- バックエンドはSupabaseを共通利用するため、Web/モバイルでデータ資産を共有可能
- 認証確認ページ:
  - `/auth`（Sign In / Sign Up）
  - `/dashboard`（セッション確認 / Sign Out）
- `/dashboard` は未ログイン時に `/auth` へリダイレクト
- メール関連フロー:
  - メール確認コールバック: `/auth/callback`
  - パスワード再設定: `/auth/update-password`

## Supabase 側のAuth設定（必須）

Supabase Dashboard > Authentication > URL Configuration で、以下を設定してください。

- Site URL:
  - ローカル: `http://localhost:3000`
  - 本番: `https://<your-production-domain>`
- Redirect URLs:
  - `http://localhost:3000/auth/callback`
  - `http://localhost:3000/auth/update-password`
  - `https://<your-production-domain>/auth/callback`
  - `https://<your-production-domain>/auth/update-password`
