"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { getBrowserSupabaseClient } from "@/lib/supabase/browser";

type AuthFormProps = {
  nextPath: string;
};

export default function AuthForm({ nextPath }: AuthFormProps) {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  const onSignUp = async () => {
    setLoading(true);
    setMessage("");
    try {
      const supabase = getBrowserSupabaseClient();
      const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${appUrl}/auth/callback?next=${encodeURIComponent(nextPath)}`,
        },
      });
      if (error) {
        setMessage(`Sign up failed: ${error.message}`);
        return;
      }
      setMessage("Sign up success. Confirm your email and continue.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  const onSignIn = async () => {
    setLoading(true);
    setMessage("");
    try {
      const supabase = getBrowserSupabaseClient();
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (error) {
        setMessage(`Sign in failed: ${error.message}`);
        return;
      }
      router.replace(nextPath);
      router.refresh();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  const onResetPassword = async () => {
    if (!email) {
      setMessage("Enter your email first.");
      return;
    }

    setLoading(true);
    setMessage("");
    try {
      const supabase = getBrowserSupabaseClient();
      const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${appUrl}/auth/update-password`,
      });
      if (error) {
        setMessage(`Reset request failed: ${error.message}`);
        return;
      }
      setMessage("Password reset email sent.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-zinc-50 p-8 text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100">
      <main className="mx-auto flex max-w-md flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
        <h1 className="text-2xl font-bold">Auth</h1>
        <p className="text-sm text-zinc-600 dark:text-zinc-300">
          Supabase Auth でメール認証をテストできます。
        </p>

        <label className="text-sm font-medium">Email</label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-950"
          placeholder="you@example.com"
        />

        <label className="text-sm font-medium">Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-950"
          placeholder="at least 6 chars"
        />

        <div className="mt-2 flex gap-2">
          <button
            type="button"
            onClick={onSignIn}
            disabled={loading}
            className="rounded-md bg-zinc-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50 dark:bg-zinc-100 dark:text-zinc-900"
          >
            Sign In
          </button>
          <button
            type="button"
            onClick={onSignUp}
            disabled={loading}
            className="rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium disabled:opacity-50 dark:border-zinc-700"
          >
            Sign Up
          </button>
          <button
            type="button"
            onClick={onResetPassword}
            disabled={loading}
            className="rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium disabled:opacity-50 dark:border-zinc-700"
          >
            Reset Password
          </button>
        </div>

        {message ? (
          <p className="rounded-md bg-zinc-100 p-3 text-sm dark:bg-zinc-800">
            {message}
          </p>
        ) : null}

        <div className="mt-4 text-sm">
          <Link href="/dashboard" className="underline">
            Go to dashboard
          </Link>
        </div>
      </main>
    </div>
  );
}
