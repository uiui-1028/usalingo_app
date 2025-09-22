import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/grid_background.dart';
import '../../presentation/theme/app_theme_provider.dart';
import 'learning_home_page.dart';
import 'design_customize_page.dart';
import 'profile_page.dart';

class RootPage extends ConsumerStatefulWidget {
  const RootPage({super.key});
  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  int _selectedIndex = 1; // 学習タブをデフォルトに設定

  static final _pages = [
    DesignCustomizePage(),
    LearningHomePage(),
    ProfilePage(),
  ];

  static const _tabItems = [
    {'icon': Icons.palette, 'label': 'デザイン', 'color': Colors.blue},
    {'icon': Icons.school, 'label': '学習', 'color': Colors.orange},
    {'icon': Icons.person, 'label': 'プロフィール', 'color': Colors.green},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Center(
          child: Image.asset(
            'assets/usalingo_app_icon/logo_white_transparent_small.png',
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: GridBackground(
        child: Stack(
          children: [
            // メインコンテンツ（下部にパディングを追加）
            Padding(
              padding: EdgeInsets.only(
                bottom: 80 + MediaQuery.of(context).padding.bottom,
              ),
              child: _pages[_selectedIndex],
            ),
            // 独立したタブバー（画面下部に固定）
            Positioned(
              left: 0,
              right: 0,
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_tabItems.length, (index) {
                      final isActive = _selectedIndex == index;
                      final item = _tabItems[index];
                      final color = item['color'] as Color;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: isActive ? 16 : 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                color: isActive
                                    ? color
                                    : ref
                                          .watch(currentThemeProvider)
                                          .textSecondaryColor,
                                size: 24,
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
