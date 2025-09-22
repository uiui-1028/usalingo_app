import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';
import 'flashcard_page.dart';

class LearningHomePage extends ConsumerStatefulWidget {
  const LearningHomePage({super.key});

  @override
  ConsumerState<LearningHomePage> createState() => _LearningHomePageState();
}

class _LearningHomePageState extends ConsumerState<LearningHomePage> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ウィジェットエリア
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // 学習デッキウィジェット
                    _buildLearningDeckWidget(context, theme),

                    // プレースホルダー（空きスロット）
                    _buildPlaceholderWidget(context, theme),

                    // その他のウィジェット用スロット
                    _buildEmptySlot(context, theme),
                    _buildEmptySlot(context, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearningDeckWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        // 学習デッキ詳細シートを表示
        _showLearningDeckDetails(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(
            color: theme.borderColor,
            width: theme.borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.style, size: 48, color: theme.primaryColor),
              const SizedBox(height: 12),
              Text(
                '学習デッキ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'フラッシュカードで学習',
                style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        // ウィジェットギャラリーを表示
        _showWidgetGallery(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(
            color: theme.borderColor,
            width: theme.borderWidth,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: theme.textSecondaryColor),
            const SizedBox(height: 8),
            Text(
              'ウィジェットの追加',
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        // ウィジェットギャラリーを表示
        _showWidgetGallery(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(
            color: theme.borderColor,
            width: theme.borderWidth,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: theme.textSecondaryColor),
            const SizedBox(height: 8),
            Text(
              'ウィジェットの追加',
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showWidgetGallery(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ウィジェットブロックライブラリー',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '学習に役立つウィジェットブロックを選択して配置できます',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // タブバー
            _buildTabBar(),
            const SizedBox(height: 16),

            // タブコンテンツ
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildTab('学習', 0),
          _buildTab('TOEIC', 1),
          _buildTab('日常会話', 2),
          _buildTab('カスタム', 3),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildLearningTab();
      case 1:
        return _buildToeicTab();
      case 2:
        return _buildDailyConversationTab();
      case 3:
        return _buildCustomTab();
      default:
        return _buildLearningTab();
    }
  }

  Widget _buildSettingSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildRadioOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final isSelected = value == groupValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                groupValue: groupValue,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    onChanged(newValue);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                value.toInt().toString(),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearningTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWidgetBlock(
            'フラッシュカード学習',
            'スワイプジェスチャーで直感的に学習',
            Icons.style,
            Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FlashcardPage()),
              );
            },
          ),
          _buildWidgetBlock(
            '学習進捗トラッカー',
            '今日の学習目標と進捗を可視化',
            Icons.trending_up,
            Colors.blue,
          ),
          _buildWidgetBlock(
            '単語カウンター',
            '学習した単語数を表示',
            Icons.calculate,
            Colors.green,
          ),
          _buildWidgetBlock(
            '復習リマインダー',
            '次回復習予定の単語を表示',
            Icons.notifications,
            Colors.orange,
          ),
          _buildWidgetBlock(
            '学習統計',
            '週間・月間の学習データ',
            Icons.bar_chart,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildToeicTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWidgetBlock(
            'TOEICスコア予測',
            '現在の学習状況からスコアを予測',
            Icons.analytics,
            Colors.red,
          ),
          _buildWidgetBlock(
            'TOEIC頻出単語',
            'TOEICでよく出る単語を表示',
            Icons.star,
            Colors.amber,
          ),
          _buildWidgetBlock(
            'TOEIC模擬テスト',
            '本番形式の模擬テストを実行',
            Icons.quiz,
            Colors.indigo,
          ),
          _buildWidgetBlock(
            'TOEIC学習計画',
            '目標スコア達成のための学習計画',
            Icons.assignment,
            Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyConversationTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWidgetBlock(
            '日常会話フレーズ',
            'よく使う日常会話のフレーズ',
            Icons.chat,
            Colors.lightBlue,
          ),
          _buildWidgetBlock(
            'シチュエーション別単語',
            '場面に応じた単語集',
            Icons.place,
            Colors.lime,
          ),
          _buildWidgetBlock(
            '発音練習',
            '音声付きの発音練習',
            Icons.record_voice_over,
            Colors.pink,
          ),
          _buildWidgetBlock('会話練習', 'AIとの会話練習', Icons.smart_toy, Colors.cyan),
        ],
      ),
    );
  }

  Widget _buildCustomTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWidgetBlock('カスタム単語集', '自分で作成した単語集', Icons.edit, Colors.brown),
          _buildWidgetBlock(
            'お気に入り単語',
            'お気に入りに登録した単語',
            Icons.favorite,
            Colors.deepOrange,
          ),
          _buildWidgetBlock('学習メモ', '学習中のメモやノート', Icons.note, Colors.blueGrey),
          _buildWidgetBlock('学習履歴', '過去の学習記録', Icons.history, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildWidgetBlock(
    String title,
    String description,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              onTap ??
              () {
                // ウィジェットブロックを選択した時の処理
                _selectWidgetBlock(title);
              },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.add_circle_outline, color: color, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectWidgetBlock(String widgetName) {
    // ウィジェットブロックを選択した時の処理
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$widgetName を追加しました'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  void _showLearningDeckDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー（タイトルとスタートボタン）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '学習デッキ詳細',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FlashcardPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('学習開始'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // デッキ情報
            _buildDeckInfoSection(context),
            const SizedBox(height: 24),

            // 学習設定
            _buildSettingSection(
              context,
              title: '学習設定',
              children: [
                _buildRadioOption(
                  context,
                  title: '通常学習',
                  subtitle: '新しいカードと復習カードを混ぜて学習',
                  value: 'normal',
                  groupValue: 'normal',
                  onChanged: (value) {},
                ),
                _buildRadioOption(
                  context,
                  title: '新規学習のみ',
                  subtitle: 'まだ学習していないカードのみ',
                  value: 'new_only',
                  groupValue: 'normal',
                  onChanged: (value) {},
                ),
                _buildRadioOption(
                  context,
                  title: '復習のみ',
                  subtitle: '既に学習済みのカードの復習',
                  value: 'review_only',
                  groupValue: 'normal',
                  onChanged: (value) {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 出題設定
            _buildSettingSection(
              context,
              title: '出題設定',
              children: [
                _buildSliderOption(
                  context,
                  title: '1回の学習セッション',
                  subtitle: 'カードの上限枚数',
                  value: 20,
                  min: 5,
                  max: 100,
                  divisions: 19,
                  onChanged: (value) {},
                ),
                _buildSliderOption(
                  context,
                  title: '1日の新規カード',
                  subtitle: '上限枚数',
                  value: 10,
                  min: 0,
                  max: 200,
                  divisions: 20,
                  onChanged: (value) {},
                ),
                _buildSliderOption(
                  context,
                  title: '1日の復習カード',
                  subtitle: '上限枚数',
                  value: 50,
                  min: 0,
                  max: 500,
                  divisions: 25,
                  onChanged: (value) {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ウェルカムデッキ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoItem(context, '総単語数', '300'),
              const SizedBox(width: 24),
              _buildInfoItem(context, '学習済み', '45'),
              const SizedBox(width: 24),
              _buildInfoItem(context, 'マスター済み', '12'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
