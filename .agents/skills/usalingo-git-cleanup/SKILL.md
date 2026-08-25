---
name: usalingo-git-cleanup
description: UsalingoリポジトリのPRマージ後または週次点検で、main、ローカルbranch、worktree、stashを監査し、完成物を失わずに安全に整理する。「git branchが多い」「(END)が出た」「マージ後の後片付け」「worktreeを片付けて」と依頼されたときに使う。チケット実装そのものや、未確認の変更を一括削除する用途には使わない。
---

# Usalingo Git Cleanup

UsalingoのGit残り物を、完成済みの機能や人の作業を失わずに整理する。対象リポジトリは `/Users/art0/development/usalingo_app`。現行アプリの確認先は `apps/ios-swiftui/` とする。

## 人に最初に伝えること

- `git branch` の末尾に出る `(END)` はエラーではない。ページ表示なので `q` で終了できる。
- 以後の一覧確認ではページ表示を避けるため `git --no-pager branch` を使う。
- branchは下書き、worktreeは作業机、mainは完成品の本棚である。PRのマージで変更はmainへ入るため、Swiftファイルを手作業でコピーしない。

## 監査

変更する前に `docs/rules/codex-credit-optimization.md` を読み、次を確認する。

```bash
git status --short --branch
git worktree list --porcelain
git --no-pager branch --format='%(refname:short)'
git stash list
```

GitHubの現在状態が必要なら `git fetch --prune origin` を実行する。branchごとに、必要な範囲だけ次を確認する。

- `git merge-base --is-ancestor <branch> origin/main`: コミットがmainの履歴に入っているか。
- `git cherry -v origin/main <branch>`: 同じ変更が別コミットとして入っていないか。
- `git diff origin/main...<branch>` と対象ファイル: mainにない内容が残っていないか。
- `gh pr list` または `gh pr view`: PRがOPEN、MERGED、CLOSEDのどれか。
- worktreeの `git status --short --branch`: 未コミット、削除、未追跡、生成キャッシュがないか。

branch名や古さだけで削除を決めない。各対象を次へ分類する。

1. **使用中**: OPENなPR、進行中チケット、または別作業の有効なworktree。残す。
2. **取り込み済み**: MERGEDなPRまたはmainに祖先として含まれる。通常削除の候補。
3. **同内容を救出済み**: コミットIDは違うが、対象機能・文書・DBがmainまたは別のMERGED PRにある。証拠を示して候補にする。
4. **未コミットあり**: `M`、`D`、`??` がある。削除せず、救出、stash、破棄の判断を分ける。
5. **不明・未統合**: mainとの差分や用途を説明できない。残して報告する。
6. **保護用**: `backup/*`、`archive/*`、既存stash、秘密情報事故の復旧用参照。依頼がない限り残す。

## 安全な整理

### main

- mainがクリーンで単純にbehindなら `git pull --ff-only origin main` を使う。
- `ahead` や `diverged` なら、独自コミットと未コミット変更を先に説明する。
- `git reset --hard origin/main` は自動実行しない。必要なら復旧用branchを作り、破棄対象を列挙し、ユーザーからその操作への明示承認を得る。
- mainへ直接コミット、push、force pushしない。

### worktree

- まずクリーンなworktreeだけを `git worktree remove <exact-path>` で削除する。最初から `--force` を使わない。
- 実体がない登録は `git worktree prune --expire now` で整理する。
- 未コミット変更がある場合は、mainまたはMERGED PRとの内容比較を行う。必要な内容は目的別branch/PRへ救出する。
- 破棄予定の差分も、可能なら名前付きstashやローカルarchiveタグへ退避し、通常削除へ戻す。
- `.codex-worktrees/` のmode `160000` gitlinkが追跡されていたら、アプリ変更と混ぜず、gitlink削除とignore追加だけの専用PRにする。
- ルートの `apps/ios-swiftui/Config/Local.xcconfig`、秘密値、ユーザーデータを削除・表示しない。worktree内の同名ファイルも、ルートに安全な設定があることと削除範囲を確認する。

### branch

- mainへの取り込みを確認したbranchは、まず `git branch -d <branch>` を使う。
- `git branch -D` は通常のマージ判定を迂回する。mainまたはMERGED PRへの救出証拠、復元用タグなどの到達可能な保存先、ユーザーの個別承認がすべてある場合だけ使う。
- `main`、OPENなPRのbranch、未確認branch、`backup/*` を削除しない。
- GitHub側で削除済みのremote-tracking branchは `git fetch --prune origin` で表示を整理する。

## 権限と停止条件

読み取り監査はそのまま進めてよい。削除、履歴置換、stash破棄、タグ削除、PRマージは対象と影響を示し、ユーザーの明示依頼または個別承認の範囲だけ実行する。

次の場合は削除せず停止し、必要な判断を短く報告する。

- mainにないSwift、migration、文書、テストがある。
- 未コミット変更の役割を説明できない。
- OPENなPRまたは別branchのbaseとして使われている。
- 秘密情報、production設定、利用者データが関係する。
- 安全審査が強制操作を拒否した。迂回せず、stash、archiveタグ、通常削除など復元可能な方法を選ぶ。

## 完了条件

- `git status --short --branch` が意図どおりである。
- `git rev-parse HEAD origin/main` でmain同期状態を説明できる。
- `git worktree list` に残した各worktreeの理由を説明できる。
- 削除したbranch/worktree、残した保護参照、復元方法を報告する。
- 未実施のテスト、GitHub操作、production操作を完了扱いにしない。

人向けの最終報告は、小学生にも分かる言葉で「片付いたもの」「安全のため残したもの」「次に必要なこと」の順に短く書く。
