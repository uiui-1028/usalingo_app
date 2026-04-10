"use client";

import { useRouter } from "next/navigation";
import { getBrowserSupabaseClient } from "@/lib/supabase/browser";

export default function SignOutButton() {
  const router = useRouter();

  const onSignOut = async () => {
    const supabase = getBrowserSupabaseClient();
    await supabase.auth.signOut();
    router.replace("/auth");
    router.refresh();
  };

  return (
    <button
      type="button"
      onClick={onSignOut}
      className="rounded-md bg-zinc-900 px-4 py-2 text-sm font-medium text-white dark:bg-zinc-100 dark:text-zinc-900"
    >
      Sign Out
    </button>
  );
}
