import {
  AccountDeletionError,
  AccountDeletionGateway,
  withdrawAccount,
  WithdrawalRequest,
  WithdrawalState,
} from "./core.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });

class SupabaseGateway implements AccountDeletionGateway {
  constructor(
    private url: string,
    private publishable: string,
    private secret: string,
  ) {}

  private async call(
    label: string,
    path: string,
    init: RequestInit = {},
    key = this.secret,
  ) {
    const response = await fetch(`${this.url}${path}`, {
      ...init,
      headers: {
        apikey: key,
        authorization: `Bearer ${key}`,
        "content-type": "application/json",
        ...init.headers,
      },
    });
    if (!response.ok) throw new Error(`${label}_${response.status}`);
    return response;
  }

  async authenticate(accessToken: string) {
    const response = await this.call("auth_user", "/auth/v1/user", {
      headers: { authorization: `Bearer ${accessToken}` },
    }, this.publishable);
    const user = await response.json();
    if (!user?.id || !user?.email) throw new Error("invalid_user");
    return { id: user.id as string, email: user.email as string };
  }

  async verifyPassword(email: string, password: string) {
    const response = await this.call(
      "password",
      "/auth/v1/token?grant_type=password",
      {
        method: "POST",
        body: JSON.stringify({ email, password }),
      },
      this.publishable,
    );
    const result = await response.json();
    if (!result?.user?.id) throw new Error("invalid_reauthentication");
    return { id: result.user.id as string };
  }

  async getDeletion(userId: string, requestId: string) {
    const response = await this.call(
      "get_deletion",
      "/rest/v1/rpc/get_account_deletion",
      {
        method: "POST",
        body: JSON.stringify({ p_user_id: userId, p_request_id: requestId }),
      },
    );
    const rows = await response.json() as WithdrawalState[];
    return rows[0] ?? null;
  }

  async requestDeletion(
    userId: string,
    requestId: string,
    reauthenticatedAt: string,
  ) {
    const response = await this.call(
      "request_deletion",
      "/rest/v1/rpc/request_account_deletion",
      {
        method: "POST",
        body: JSON.stringify({
          p_user_id: userId,
          p_request_id: requestId,
          p_reauthenticated_at: reauthenticatedAt,
        }),
      },
    );
    const rows = await response.json() as WithdrawalState[];
    if (!rows[0]) throw new Error("missing_deletion_state");
    return rows[0];
  }

  async banUser(userId: string) {
    await this.call(
      "ban_user",
      `/auth/v1/admin/users/${encodeURIComponent(userId)}`,
      {
        method: "PUT",
        body: JSON.stringify({ ban_duration: "876000h" }),
      },
    );
  }

  async revokeSessions(accessToken: string) {
    const response = await fetch(`${this.url}/auth/v1/logout?scope=global`, {
      method: "POST",
      headers: { apikey: this.secret, authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok && response.status !== 401) {
      throw new Error(`upstream_${response.status}`);
    }
  }

  async advance(
    userId: string,
    requestId: string,
    step: "auth_banned" | "sessions_revoked" | "failed",
    failureCode?: string,
  ) {
    await this.call(
      "advance_deletion",
      "/rest/v1/rpc/advance_account_deletion",
      {
        method: "POST",
        body: JSON.stringify({
          p_user_id: userId,
          p_request_id: requestId,
          p_step: step,
          p_failure_code: failureCode ?? null,
        }),
      },
    );
  }

  async purgeExpiredUser(userId: string) {
    await this.call("claim_purge", "/rest/v1/rpc/claim_expired_account_purge", {
      method: "POST",
      body: JSON.stringify({ p_user_id: userId }),
    });
    await this.call(
      "delete_auth_user",
      `/auth/v1/admin/users/${encodeURIComponent(userId)}`,
      {
        method: "DELETE",
      },
    );
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ code: "method_not_allowed" }, 405);
  }
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json({ code: "unauthorized" }, 401);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const publishable = Deno.env.get("SUPABASE_ANON_KEY");
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publishable || !secret) {
    return json({ code: "service_unavailable" }, 503);
  }

  try {
    const input = await request.json() as WithdrawalRequest;
    if (
      (input as WithdrawalRequest & { operation?: string }).operation ===
        "purge"
    ) {
      if (authorization.slice(7) !== secret || !input.user_id) {
        return json({ code: "forbidden" }, 403);
      }
      await new SupabaseGateway(url, publishable, secret).purgeExpiredUser(
        input.user_id,
      );
      return json({ status: "purged" });
    }
    const result = await withdrawAccount(
      new SupabaseGateway(url, publishable, secret),
      authorization.slice(7),
      input,
    );
    return json({
      request_id: result.request_id,
      status: result.status,
      restorable_until: result.restorable_until,
    });
  } catch (error) {
    if (error instanceof AccountDeletionError) {
      return json({ code: error.code }, error.status);
    }
    console.error(
      "delete-user-account failed",
      error instanceof Error && /^[-a-z0-9_]+$/i.test(error.message)
        ? error.message
        : "unexpected_error",
    );
    return json({ code: "service_unavailable" }, 503);
  }
});
