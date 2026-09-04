import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  AccountDeletionError,
  AccountDeletionGateway,
  deleteAccount,
} from "./core.ts";

type Calls = string[];

function makeGateway(
  calls: Calls,
  overrides: Partial<AccountDeletionGateway> = {},
): AccountDeletionGateway {
  return {
    authenticate: () => {
      calls.push("authenticate");
      return Promise.resolve({ id: "user-1", email: "user@example.test" });
    },
    verifyPassword: () => {
      calls.push("verifyPassword");
      return Promise.resolve({ id: "user-1" });
    },
    deleteOwnedStorageObjects: () => {
      calls.push("deleteOwnedStorageObjects");
      return Promise.resolve();
    },
    deleteAuthUser: () => {
      calls.push("deleteAuthUser");
      return Promise.resolve();
    },
    ...overrides,
  };
}

const validInput = { confirmation: "退会", password: "correct horse" };

Deno.test("deletes storage objects before the auth user", async () => {
  const calls: Calls = [];
  const receipt = await deleteAccount(
    makeGateway(calls),
    "token",
    validInput,
    new Date("2026-09-04T00:00:00Z"),
  );

  assertEquals(calls, [
    "authenticate",
    "verifyPassword",
    "deleteOwnedStorageObjects",
    "deleteAuthUser",
  ]);
  assertEquals(receipt, {
    status: "deleted",
    deleted_at: "2026-09-04T00:00:00.000Z",
  });
});

Deno.test("rejects a wrong confirmation phrase before touching anything", async () => {
  const calls: Calls = [];
  const error = await assertRejects(
    () => deleteAccount(makeGateway(calls), "token", { ...validInput, confirmation: "たいかい" }),
    AccountDeletionError,
  );
  assertEquals(error.status, 400);
  assertEquals(error.code, "invalid_request");
  assertEquals(calls, []);
});

Deno.test("rejects an empty password before touching anything", async () => {
  const calls: Calls = [];
  const error = await assertRejects(
    () => deleteAccount(makeGateway(calls), "token", { ...validInput, password: "" }),
    AccountDeletionError,
  );
  assertEquals(error.status, 400);
  assertEquals(calls, []);
});

Deno.test("rejects an invalid session", async () => {
  const calls: Calls = [];
  const error = await assertRejects(
    () =>
      deleteAccount(
        makeGateway(calls, { authenticate: () => Promise.reject(new Error("nope")) }),
        "token",
        validInput,
      ),
    AccountDeletionError,
  );
  assertEquals(error.status, 401);
  assertEquals(error.code, "unauthorized");
});

Deno.test("refuses to delete somebody else's account", async () => {
  const calls: Calls = [];
  const error = await assertRejects(
    () => deleteAccount(makeGateway(calls), "token", { ...validInput, user_id: "user-2" }),
    AccountDeletionError,
  );
  assertEquals(error.status, 403);
  assertEquals(error.code, "target_mismatch");
  assertEquals(calls, ["authenticate"]);
});

Deno.test("requires the password to match before deleting", async () => {
  const calls: Calls = [];
  const error = await assertRejects(
    () =>
      deleteAccount(
        makeGateway(calls, { verifyPassword: () => Promise.reject(new Error("bad")) }),
        "token",
        validInput,
      ),
    AccountDeletionError,
  );
  assertEquals(error.status, 403);
  assertEquals(error.code, "reauthentication_failed");
  // 差し替えた verifyPassword は calls へ記録しないため、認証までで止まったことを示す。
  assertEquals(calls, ["authenticate"]);
});

Deno.test("does not delete when the password belongs to another account", async () => {
  const calls: Calls = [];
  const error = await assertRejects(
    () =>
      deleteAccount(
        makeGateway(calls, { verifyPassword: () => Promise.resolve({ id: "user-2" }) }),
        "token",
        validInput,
      ),
    AccountDeletionError,
  );
  assertEquals(error.code, "reauthentication_failed");
  // 差し替えた verifyPassword は calls へ記録しない。削除まで進んでいないことが要点。
  assertEquals(calls, ["authenticate"]);
});

Deno.test("reports a failure so the user can simply try again", async () => {
  const calls: Calls = [];
  const error = await assertRejects(
    () =>
      deleteAccount(
        makeGateway(calls, { deleteAuthUser: () => Promise.reject(new Error("boom")) }),
        "token",
        validInput,
      ),
    AccountDeletionError,
  );
  assertEquals(error.status, 503);
  assertEquals(error.code, "deletion_failed");
});
