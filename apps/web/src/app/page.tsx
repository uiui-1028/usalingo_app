import { getSupabaseClient } from "@/lib/supabase/client";
import Link from "next/link";

export default async function Home() {
  let status = "Supabase connection not tested";

  try {
    const supabase = getSupabaseClient();
    const { error } = await supabase.from("words").select("id").limit(1);
    status = error
      ? `Supabase connected (query error: ${error.message})`
      : "Supabase connected successfully";
  } catch (error) {
    status = `Supabase init error: ${error instanceof Error ? error.message : "unknown error"}`;
  }

  return (
    <div className="min-h-screen bg-zinc-50 p-8 text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100">
      <main className="mx-auto flex max-w-3xl flex-col gap-6 rounded-2xl border border-zinc-200 bg-white p-8 shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
        <h1 className="text-3xl font-bold">Usalingo Web (Next.js)</h1>
        <p className="text-zinc-600 dark:text-zinc-300">
          Web版を先行で育てつつ、将来のモバイル展開に再利用できる構成です。
        </p>
        <div className="rounded-lg bg-zinc-100 p-4 text-sm dark:bg-zinc-800">
          <p className="font-semibold">Connection check</p>
          <p>{status}</p>
        </div>
        <p className="text-sm text-zinc-500 dark:text-zinc-400">
          環境変数は <code>.env.local</code> に設定してください（
          <code>.env.example</code> を参照）。
        </p>
        <div className="flex gap-3">
          <Link
            href="/auth"
            className="rounded-md bg-zinc-900 px-4 py-2 text-sm font-medium text-white dark:bg-zinc-100 dark:text-zinc-900"
          >
            Auth page
          </Link>
          <Link
            href="/dashboard"
            className="rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium dark:border-zinc-700"
          >
            Dashboard
          </Link>
        </div>
      </main>
    </div>
  );
}
