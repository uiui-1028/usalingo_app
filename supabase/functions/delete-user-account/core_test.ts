import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.14";
import {
  AccountDeletionError,
  AccountDeletionGateway,
  withdrawAccount,
  WithdrawalState,
} from "./core.ts";

class FakeGateway implements AccountDeletionGateway {
  calls: string[] = [];
  state: WithdrawalState = {
    request_id: "550e8400-e29b-41d4-a716-446655440000",
    status: "requested",
    restorable_until: "2027-08-25T00:00:00Z",
    disabled_at: null,
    sessions_revoked_at: null,
  };
  user = { id: "user-a", email: "a@example.test" };
  failAt: string | null = null;
  async authenticate() {
    this.calls.push("authenticate");
    if (this.failAt === "authenticate") throw new Error();
    return this.user;
  }
  async verifyPassword() {
    this.calls.push("verifyPassword");
    if (this.failAt === "verifyPassword") throw new Error();
    return { id: this.user.id };
  }
  async getDeletion(): Promise<WithdrawalState | null> {
    this.calls.push("getDeletion");
    return null;
  }
  async requestDeletion() {
    this.calls.push("requestDeletion");
    return { ...this.state };
  }
  async banUser() {
    this.calls.push("banUser");
    if (this.failAt === "banUser") throw new Error();
  }
  async revokeSessions() {
    this.calls.push("revokeSessions");
    if (this.failAt === "revokeSessions") throw new Error();
  }
  async advance(
    _userId: string,
    _requestId: string,
    step: "auth_banned" | "sessions_revoked" | "failed",
  ) {
    this.calls.push(`advance:${step}`);
  }
}

const input = {
  request_id: "550e8400-e29b-41d4-a716-446655440000",
  confirmation: "退会",
  password: "not-logged",
  user_id: "user-a",
};

Deno.test("uses authenticated identity and completes ordered withdrawal", async () => {
  const gateway = new FakeGateway();
  const result = await withdrawAccount(
    gateway,
    "not-logged",
    input,
    new Date("2026-08-25T00:00:00Z"),
  );
  assertEquals(result.status, "disabled");
  assertEquals(gateway.calls, [
    "authenticate",
    "getDeletion",
    "verifyPassword",
    "requestDeletion",
    "banUser",
    "advance:auth_banned",
    "revokeSessions",
    "advance:sessions_revoked",
  ]);
});

Deno.test("rejects a body target that differs from JWT identity", async () => {
  const gateway = new FakeGateway();
  await assertRejects(
    () => withdrawAccount(gateway, "token", { ...input, user_id: "user-b" }),
    AccountDeletionError,
    "target_mismatch",
  );
  assertEquals(gateway.calls, ["authenticate"]);
});

Deno.test("rejects missing authentication and failed reauthentication", async () => {
  const unauthenticated = new FakeGateway();
  unauthenticated.failAt = "authenticate";
  await assertRejects(
    () => withdrawAccount(unauthenticated, "bad", input),
    AccountDeletionError,
    "unauthorized",
  );
  const stale = new FakeGateway();
  stale.failAt = "verifyPassword";
  await assertRejects(
    () => withdrawAccount(stale, "token", input),
    AccountDeletionError,
    "reauthentication_failed",
  );
});

Deno.test("retries only unfinished steps after a partial failure", async () => {
  const gateway = new FakeGateway();
  gateway.state.disabled_at = "2026-08-25T00:00:00Z";
  await withdrawAccount(gateway, "token", input);
  assertEquals(gateway.calls.includes("banUser"), false);
  assertEquals(gateway.calls.includes("revokeSessions"), true);
});

Deno.test("returns the saved result for an idempotent retry before reauthentication", async () => {
  const gateway = new FakeGateway();
  gateway.getDeletion = async () => {
    gateway.calls.push("getDeletion");
    return { ...gateway.state, disabled_at: "2026-08-25T00:00:00Z" };
  };
  const result = await withdrawAccount(gateway, "old-token", input);
  assertEquals(result.request_id, input.request_id);
  assertEquals(gateway.calls, ["authenticate", "getDeletion"]);
});

Deno.test("records a safe failure code without leaking secrets", async () => {
  const gateway = new FakeGateway();
  gateway.failAt = "banUser";
  await assertRejects(
    () => withdrawAccount(gateway, "secret-token", input),
    AccountDeletionError,
    "withdrawal_in_progress",
  );
  assertEquals(gateway.calls.at(-1), "advance:failed");
  assertEquals(
    gateway.calls.some((call) =>
      call.includes("secret-token") || call.includes(input.password)
    ),
    false,
  );
});
