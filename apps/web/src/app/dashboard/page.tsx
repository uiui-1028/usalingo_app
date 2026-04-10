import Link from "next/link";
import { redirect } from "next/navigation";
import { getServerSupabaseClient } from "@/lib/supabase/server";
import SignOutButton from "./sign-out-button";

export default async function DashboardPage() {
  const supabase = await getServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/auth?next=/dashboard");
  }

  return (
    <div className="min-h-screen bg-zinc-50 p-8 text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100">
      <main className="mx-auto flex max-w-2xl flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <p className="text-sm text-zinc-600 dark:text-zinc-300">
          ログイン状態の確認ページです。
        </p>

        <div className="rounded-md bg-zinc-100 p-3 text-sm dark:bg-zinc-800">
          <p>
            Signed in as: <strong>{user.email}</strong>
          </p>
          <p>User ID: {user.id}</p>
        </div>

        <div className="flex gap-2">
          <SignOutButton />
          <Link href="/auth" className="rounded-md border px-4 py-2 text-sm">
            Back to auth
          </Link>
        </div>
      </main>
    </div>
  );
}
