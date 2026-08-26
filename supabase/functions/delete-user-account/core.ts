export type WithdrawalRequest = {
  request_id: string;
  confirmation: string;
  password: string;
  user_id?: string;
};

export type WithdrawalState = {
  request_id: string;
  status: string;
  restorable_until: string;
  disabled_at: string | null;
  sessions_revoked_at: string | null;
};

export interface AccountDeletionGateway {
  authenticate(accessToken: string): Promise<{ id: string; email: string }>;
  verifyPassword(email: string, password: string): Promise<{ id: string }>;
  getDeletion(
    userId: string,
    requestId: string,
  ): Promise<WithdrawalState | null>;
  requestDeletion(
    userId: string,
    requestId: string,
    reauthenticatedAt: string,
  ): Promise<WithdrawalState>;
  banUser(userId: string): Promise<void>;
  revokeSessions(accessToken: string): Promise<void>;
  advance(
    userId: string,
    requestId: string,
    step: "auth_banned" | "sessions_revoked" | "failed",
    failureCode?: string,
  ): Promise<void>;
}

export class AccountDeletionError extends Error {
  constructor(public status: number, public code: string) {
    super(code);
  }
}

export async function withdrawAccount(
  gateway: AccountDeletionGateway,
  accessToken: string,
  input: WithdrawalRequest,
  now = new Date(),
): Promise<WithdrawalState> {
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(
        input.request_id,
      ) || input.confirmation !== "退会" || !input.password
  ) {
    throw new AccountDeletionError(400, "invalid_request");
  }

  const user = await gateway.authenticate(accessToken).catch(() => {
    throw new AccountDeletionError(401, "unauthorized");
  });
  if (input.user_id && input.user_id !== user.id) {
    throw new AccountDeletionError(403, "target_mismatch");
  }

  const existing = await gateway.getDeletion(user.id, input.request_id);
  if (existing) return existing;

  const reauthenticated = await gateway.verifyPassword(
    user.email,
    input.password,
  ).catch(() => {
    throw new AccountDeletionError(403, "reauthentication_failed");
  });
  if (reauthenticated.id !== user.id) {
    throw new AccountDeletionError(403, "reauthentication_failed");
  }

  const state = await gateway.requestDeletion(
    user.id,
    input.request_id,
    now.toISOString(),
  );
  try {
    if (!state.disabled_at) {
      await gateway.banUser(user.id);
      await gateway.advance(user.id, state.request_id, "auth_banned");
      state.disabled_at = now.toISOString();
      state.status = "disabled";
    }
    if (!state.sessions_revoked_at) {
      await gateway.revokeSessions(accessToken);
      await gateway.advance(user.id, state.request_id, "sessions_revoked");
      state.sessions_revoked_at = now.toISOString();
    }
    return state;
  } catch (error) {
    await gateway.advance(
      user.id,
      state.request_id,
      "failed",
      "withdrawal_step_failed",
    ).catch(() => {});
    throw new AccountDeletionError(503, "withdrawal_in_progress");
  }
}
