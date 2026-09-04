export type DeletionRequest = {
  confirmation: string;
  password: string;
  user_id?: string;
};

export type DeletionReceipt = {
  status: "deleted";
  deleted_at: string;
};

/// 退会はその場で全部消す（2026-09-04 改定）。
/// 停止状態も復元期間も持たないため、進捗を記録する必要がない。
export interface AccountDeletionGateway {
  authenticate(accessToken: string): Promise<{ id: string; email: string }>;
  verifyPassword(email: string, password: string): Promise<{ id: string }>;
  /// 利用者が持つStorage objectを消す。残っていると Auth の利用者削除が失敗し得る。
  deleteOwnedStorageObjects(userId: string): Promise<void>;
  /// auth.users を消す。public.users 以下は on delete cascade で連鎖して消える。
  deleteAuthUser(userId: string): Promise<void>;
}

export class AccountDeletionError extends Error {
  constructor(public status: number, public code: string) {
    super(code);
  }
}

export async function deleteAccount(
  gateway: AccountDeletionGateway,
  accessToken: string,
  input: DeletionRequest,
  now = new Date(),
): Promise<DeletionReceipt> {
  if (input?.confirmation !== "退会" || !input?.password) {
    throw new AccountDeletionError(400, "invalid_request");
  }

  const user = await gateway.authenticate(accessToken).catch(() => {
    throw new AccountDeletionError(401, "unauthorized");
  });
  if (input.user_id && input.user_id !== user.id) {
    throw new AccountDeletionError(403, "target_mismatch");
  }

  // 消す直前に本人確認をやり直す。盗まれた端末からの退会を防ぐ。
  const reauthenticated = await gateway.verifyPassword(
    user.email,
    input.password,
  ).catch(() => {
    throw new AccountDeletionError(403, "reauthentication_failed");
  });
  if (reauthenticated.id !== user.id) {
    throw new AccountDeletionError(403, "reauthentication_failed");
  }

  // 途中で失敗しても状態は残さない。利用者はそのまま再実行すればよい。
  try {
    await gateway.deleteOwnedStorageObjects(user.id);
    await gateway.deleteAuthUser(user.id);
  } catch {
    throw new AccountDeletionError(503, "deletion_failed");
  }

  return { status: "deleted", deleted_at: now.toISOString() };
}
