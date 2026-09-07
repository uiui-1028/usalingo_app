# 利用者が自分のデッキを持てるようにする計画

作成日: 2026-09-07
対象: Supabase (`decks` / `cards`) と SwiftUIアプリ `apps/ios-swiftui/`
状態: 本番Supabase適用済み（2026-09-07）。アプリ実装済み・未マージ

## 1. なぜやるか

同じアプリなのに、ログインの有無でデッキの扱いが別物になっている。

| | ゲスト | ログイン中 |
|---|---|---|
| デッキの置き場所 | 端末（`LocalStudyDataSource`） | Supabase `decks` |
| デッキの追加・取り込み | できる | **できない** |
| 並べ替え・削除・書き出し | できる | **できない** |
| 進捗の保存先 | 端末（バックアップはリモート） | リモート |

原因はアプリではなくDBにある。`public.decks` に所有者の列がなく、
[公式コンテンツ契約](../architecture/official-content-contract.md) で
`authenticated` には `select` だけをGRANTしているため、ログイン中の利用者は
デッキを作れない。だからアプリ側は `appState.isGuest` で入口を隠すしかなかった。

利用者から見ると「ログインしたらデッキを追加できなくなった」であり、これは直す。

## 2. マイルストーンとの関係（先に人間の判断が要る）

この計画は、現在のスコープでは**やらないと決めてあるもの**に当たる。

- [milestones.md](milestones.md) の M2「含めないこと」に
  「利用者が自分の単語やデッキを作る機能」がある
- [anki-data-model.md](../architecture/anki-data-model.md) の対象外に
  「ユーザー独自デッキ」がある

つまり本計画は、M1/M2の外にある新しい範囲を開く。着手には
「M1/M2より先にやるか、M2の後に回すか」の判断が要る。判断が済むまでは、
この文書は設計の置き場所として残し、migrationの本番適用とアプリ実装は始めない。

暫定の逃げ道としては、ログイン中も追加行を出して押したときに
「いまはログイン中のデッキ追加に対応していない」と理由を出す案がある。状態差は
残るが「消えた」という誤解はなくなる。

## 3. 決めたこと

### 3.1 所有者列は `decks` にだけ置く

`public.decks` に `owner_id uuid null references public.users(id)` を足す。

- `owner_id is null` = 公式デッキ。従来どおり全員が読めて、誰も書けない
- `owner_id = auth.uid()` = 本人のデッキ。本人だけが読み書きできる

`cards` には所有者列を**置かない**。カードの所有者は `deck_id` から引く。

```sql
exists (select 1 from public.decks d
        where d.id = cards.deck_id and d.owner_id = auth.uid())
```

理由: `cards.owner_id` を持つと `decks.owner_id` と二重管理になり、ずれたときに
公式カードが本人カードとして見えるなどの事故が起きる。所有者の正本は1か所にする。

### 3.2 別テーブル（`user_decks`）にしない理由

`user_decks` / `user_cards` を新設すると公式テーブルには触らずに済むが、
`user_card_progress.card_id` が `cards.id` を指しているため、進捗の参照先が
2つに割れる。進捗は学習の核であり、ここを分岐させる代償のほうが大きい。

公式コンテンツ契約は「公式行は読み取り専用」を守れば維持できる。本計画のRLSは
`owner_id is null` の行への書き込みを一切許可しない。

### 3.3 v1では「公式の単語から選んで作る」だけにする

> [!NOTE]
> 2026-09-07 に[ゲストを匿名アカウントにする](../decisions/guest-is-an-anonymous-account-20260907.md)
> が決まった。ゲストも `authenticated` になるため、下の「ログイン中」は
> **匿名アカウントを含む全員**を指すようになる。同梱サンプルJSONを取り込む導線は
> 段階4で「単語を選んで作る」へ置き換える。


ログイン中のデッキ作成は、既存の `words` から単語を選ぶ形に限る。

- JSONの取り込みと書き出しは、当面ゲスト（端末）だけに残す
- 理由: 取り込んだJSONの単語が `words` にあるとは限らず、無い単語を
  `words` へ入れるのは公式コンテンツの書き込みになる。ここを開けると
  公式コンテンツ契約が崩れる

## 4. スキーマ変更

```sql
alter table public.decks
  add column owner_id uuid references public.users(id) on delete cascade;

-- 公式デッキ名の全体ユニークをやめ、所有者ごとのユニークにする。
-- NULL（公式）どうしも重複扱いにするため nulls not distinct を使う。
alter table public.decks drop constraint decks_deck_name_key;
alter table public.decks
  add constraint decks_owner_deck_name_key
  unique nulls not distinct (owner_id, deck_name);

create index decks_owner_id_idx on public.decks (owner_id);
```

`cards` は変更しない。`cards.deck_id` の外部キーは `restrict` のままにし、
本人デッキの削除は「進捗 → カード → デッキ」の順にアプリから消す。

濫用防止の上限をトリガーで置く。

- 1利用者あたりデッキ50件まで
- 1デッキあたりカード2,000枚まで

## 5. RLSとGRANT

公式行（`owner_id is null`）は読み取りだけ。本人行は読み書き。

| テーブル | select | insert | update | delete |
|---|---|---|---|---|
| `decks` | 公式 + 本人 | 本人のみ（`owner_id = auth.uid()`） | 本人のみ | 本人のみ |
| `cards` | 公式 + 本人デッキ配下 | 本人デッキ配下のみ | 本人デッキ配下のみ | 本人デッキ配下のみ |
| `words` など | 変更しない（読み取りのみ） | — | — | — |

GRANTも合わせて広げる。`decks` と `cards` の `authenticated` へ
`insert, update, delete` を足す。RLSとGRANTは別の門なので、両方を更新しないと
機能しない。

`with check` は `insert` と `update` の両方に付け、`owner_id` を
`auth.uid()` 以外へ書き換えられないようにする（自分の行を公式行へ昇格させない）。

## 6. アプリの変更

### 6.1 データ層

`StudyDataSource` にデッキ操作を足し、両実装で満たす。

```swift
func createDeck(name: String, description: String?) async throws -> Deck
func addWords(deckId: Int, wordIds: [Int]) async throws
func deleteDeck(id: Int) async throws
func canEditDeck(_ deck: Deck) -> Bool   // 公式デッキは false
```

- `RemoteStudyDataSource`: `decks` / `cards` へのinsert・delete
- `LocalStudyDataSource`: 既存のローカル操作へ割り当てる

### 6.2 画面

`LearningDashboardView` の `appState.isGuest` による出し分けをやめ、
「そのデッキを扱えるか」をデータ層に聞いて出し分ける。

| 操作 | ゲスト | ログイン中（個人デッキ） | 公式デッキ |
|---|---|---|---|
| 追加 | できる | できる | — |
| 削除 | できる | できる | できない |
| 並べ替え | できる | **v1では扱わない** | できない |
| JSON書き出し | できる | **v1では扱わない** | できない |
| JSON取り込み | できる | **v1では扱わない** | — |

並べ替えと書き出しをリモートで扱わないのは、`decks` に並び順の列がなく
（本計画の「9. まだ決めていないこと」）、書き出しは端末のデッキファイルを
元にしているため。どちらも「できない」ではなく「まだ設計していない」であり、
画面には操作そのものを出さない。

### 6.3 ゲストからの引き継ぎ

**不要になった。** ゲストが匿名アカウントになれば、デッキも学習記録も最初から
同じ場所（同じ `user_id`）にあるため、移送するものがない。移送処理は必ず
どこかで取りこぼすので、取りこぼしようがない作りを選ぶ。

詳細は [ゲストを匿名アカウントにする実行計画](guest-as-anonymous-account-plan.md)。

## 7. 段階

| 段階 | 内容 | 完了の目安 |
|---|---|---|
| 1 | migration作成とローカル検証 | **完了**。[20260907000000_add_user_owned_decks.sql](../../supabase/migrations/20260907000000_add_user_owned_decks.sql) と [user_owned_decks.test.sql](../../supabase/tests/user_owned_decks.test.sql)。ローカルで全13件通過 |
| 2 | 本番Supabaseへ適用 | **完了（2026-09-07）**。`supabase db push --linked` で適用し、列・RLS・GRANT・トリガー・一意制約を読み取りで確認。公式デッキ1件とカード50件は変化なし |
| 3 | アプリ実装 | **実装済み・未マージ**。ゲスト状態での表示はシミュレータで確認済み。ログイン状態での通し確認は、パスワードを扱えないため未実施 |
| 4 | ゲストからの引き継ぎ | **取り下げ**。匿名アカウント化で不要になった（6.3を見る） |

段階2より先にアプリを出すと、ログイン中の利用者が存在しない権限を叩いて
失敗する。順番は入れ替えない。

## 8. 検証項目

- 本人が自分のデッキを作成・改名・削除できる
- 本人が他人のデッキを読めない・書けない
- `authenticated` が `owner_id is null` の行を更新・削除できない
- `owner_id` を他人のIDや `null` へ書き換えられない
- 公式デッキの一覧・学習・進捗が従来どおり動く
- 上限（デッキ50、カード2,000）を超える追加が拒否される
- 本人デッキの削除で、そのデッキの進捗とカードが残らない

## 9. まだ決めていないこと

- 本人デッキを他人へ共有・公開するか（v1では扱わない）
- 本人デッキの並び順をリモートに持つか、端末だけに持つか
- 公式デッキを複製して自分用に編集する導線を作るか
