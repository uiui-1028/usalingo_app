import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../presentation/theme/app_theme_provider.dart';
import '../presentation/pages/root_page.dart';
import '../secrets.dart';

class SupabaseEnv {
  static const String url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
}

// Supabase初期化クラス
class SupabaseInitializer {
  static SupabaseClient? _client;
  
  static SupabaseClient get client {
    if (_client == null) {
      throw StateError('Supabase is not initialized. Call initialize() first.');
    }
    return _client!;
  }
  
  static Future<void> initialize() async {
    final url = SupabaseEnv.url.isNotEmpty
        ? SupabaseEnv.url
        : SupabaseSecrets.supabaseUrl;
    final anonKey = SupabaseEnv.anonKey.isNotEmpty
        ? SupabaseEnv.anonKey
        : SupabaseSecrets.supabaseAnonKey;

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _client = Supabase.instance.client;
  }
}

// アプリケーションのメイン設定クラス
class UsalingoApp extends ConsumerWidget {
  const UsalingoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(currentThemeProvider);
    
    return MaterialApp(
      title: 'Usalingo',
      theme: currentTheme.themeData,
      home: const RootPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// アプリケーションの設定
class AppConfig {
  // アプリ名
  static const String appName = 'Usalingo';
  
  // アプリバージョン
  static const String appVersion = '1.0.0';
  
  // アプリの説明
  static const String appDescription = 'Effortless Learning - 英語学習を楽しく、簡単に';
  
  // サポートメールアドレス
  static const String supportEmail = 'support@usalingo.com';
  
  // プライバシーポリシーURL
  static const String privacyPolicyUrl = 'https://usalingo.com/privacy';
  
  // 利用規約URL
  static const String termsOfServiceUrl = 'https://usalingo.com/terms';
  
  // アプリの最小サポートバージョン
  static const String minSupportedVersion = '1.0.0';
  
  // アプリの推奨バージョン
  static const String recommendedVersion = '1.0.0';
}
