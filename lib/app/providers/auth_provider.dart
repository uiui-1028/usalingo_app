import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart';

// Supabaseクライアントのプロバイダー
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseInitializer.client;
});

// 認証状態のプロバイダー
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

// 現在のユーザーのプロバイダー
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

// 認証サービスクラス
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  // サインアップ
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  // サインイン
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // サインアウト
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // パスワードリセット
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // 現在のユーザーを取得
  User? get currentUser => _client.auth.currentUser;

  // 認証状態を監視
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

// 認証サービスのプロバイダー
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client);
});
