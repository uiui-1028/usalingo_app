import {
  AccountDeletionError,
  AccountDeletionGateway,
  deleteAccount,
  DeletionRequest,
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

  async deleteOwnedStorageObjects(userId: string) {
    await this.call(
      "delete_storage_objects",
      `/rest/v1/objects?owner_id=eq.${encodeURIComponent(userId)}`,
      { method: "DELETE", headers: { "accept-profile": "storage", "content-profile": "storage" } },
    );
  }

  async deleteAuthUser(userId: string) {
    await this.call(
      "delete_auth_user",
      `/auth/v1/admin/users/${encodeURIComponent(userId)}`,
      { method: "DELETE" },
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
    const input = await request.json() as DeletionRequest;
    const receipt = await deleteAccount(
      new SupabaseGateway(url, publishable, secret),
      authorization.slice(7),
      input,
    );
    return json(receipt);
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
