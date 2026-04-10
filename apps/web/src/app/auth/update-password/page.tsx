"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { getBrowserSupabaseClient } from "@/lib/supabase/browser";

export default function UpdatePasswordPage() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  const onUpdatePassword = async () => {
    if (password.length < 6) {
      setMessage("Password must be at least 6 characters.");
      return;
    }

    setLoading(true);
    setMessage("");

    try {
      const supabase = getBrowserSupabaseClient();
      const { error } = await supabase.auth.updateUser({ password });
      if (error) {
        setMessage(`Password update failed: ${error.message}`);
        return;
      }

      setMessage("Password updated. Redirecting to dashboard...");
      setTimeout(() => {
        router.replace("/dashboard");
        router.refresh();
      }, 600);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-zinc-50 p-8 text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100">
      <main className="mx-auto flex max-w-md flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
        <h1 className="text-2xl font-bold">Update Password</h1>
        <p className="text-sm text-zinc-600 dark:text-zinc-300">
          メール内リンク経由でこのページを開いた後、新しいパスワードを設定します。
        </p>

        <label className="text-sm font-medium">New password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-950"
          placeholder="at least 6 chars"
        />

        <button
          type="button"
          onClick={onUpdatePassword}
          disabled={loading}
          className="rounded-md bg-zinc-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50 dark:bg-zinc-100 dark:text-zinc-900"
        >
          Update Password
        </button>

        {message ? (
          <p className="rounded-md bg-zinc-100 p-3 text-sm dark:bg-zinc-800">
            {message}
          </p>
        ) : null}
      </main>
    </div>
  );
}
