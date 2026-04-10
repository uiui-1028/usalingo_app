import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

// アプリケーションのエントリーポイント
void main() async {
  // Flutterエンジンの初期化
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseInitializer.initialize();
  
  // アプリケーションの起動
  runApp(
    const ProviderScope(
      child: UsalingoApp(),
    ),
  );
}
