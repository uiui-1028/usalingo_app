import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../domain/entities/word.dart';

class WordListPage extends ConsumerStatefulWidget {
  const WordListPage({super.key});

  @override
  ConsumerState<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends ConsumerState<WordListPage> {
  @override
  Widget build(BuildContext context) {
    final wordListAsync = ref.watch(wordListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('単語リスト')),
      body: wordListAsync.when(
        data: (words) => ReorderableListView.builder(
          itemCount: words.length,
          onReorder: (oldIndex, newIndex) {
            // TODO: 順序変更の永続化（DB更新）
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = words.removeAt(oldIndex);
              words.insert(newIndex, item);
            });
          },
          itemBuilder: (context, i) {
            final word = words[i];
            return Card(
              key: ValueKey(word.id),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
              child: Dismissible(
                key: ValueKey(word.id),
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (_) async {
                  final repo = ref.read(wordRepositoryProvider);
                  await repo.deleteWord(word.id!);
                  ref.invalidate(wordListProvider);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // ドラッグハンドル（左端）
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: const Icon(
                          Icons.drag_handle,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                      // アバター
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          word.text[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // メインコンテンツ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              word.meaning,
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (word.sentence != null &&
                                word.sentence!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                word.sentence!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (word.tags != null && word.tags!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: word.tags!
                                    .split(',')
                                    .map(
                                      (tag) => Chip(
                                        label: Text(tag.trim()),
                                        backgroundColor: Colors.blue[50],
                                        labelStyle: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 編集ボタン（右端）
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showWordDialog(context, ref, word: word),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWordDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showWordDialog(BuildContext context, WidgetRef ref, {Word? word}) {
    final textController = TextEditingController(text: word?.text ?? '');
    final meaningController = TextEditingController(text: word?.meaning ?? '');
    final sentenceController = TextEditingController(
      text: word?.sentence ?? '',
    );
    final imageUrlController = TextEditingController(
      text: word?.imageUrl ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(word == null ? '単語追加' : '単語編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(labelText: '英単語'),
            ),
            TextField(
              controller: meaningController,
              decoration: const InputDecoration(labelText: '意味'),
            ),
            TextField(
              controller: sentenceController,
              decoration: const InputDecoration(labelText: '例文'),
            ),
            TextField(
              controller: imageUrlController,
              decoration: const InputDecoration(labelText: '画像URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(wordRepositoryProvider);
              if (word == null) {
                await repo.insertWord(
                  Word(
                    text: textController.text,
                    meaning: meaningController.text,
                    sentence: sentenceController.text,
                    imageUrl: imageUrlController.text,
                  ),
                );
              } else {
                await repo.updateWord(
                  word.copyWith(
                    text: textController.text,
                    meaning: meaningController.text,
                    sentence: sentenceController.text,
                    imageUrl: imageUrlController.text,
                  ),
                );
              }
              ref.invalidate(wordListProvider);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
