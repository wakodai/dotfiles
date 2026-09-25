---
name: obsidian-frontmatter
description: Obsidian 保管庫内の markdown ファイルのフロントマター（created / tags）を整備するスキル。created フィールドをファイル作成日時から付与し、created_at などのキー名ゆれを created に統一し、ファイル内容から tags を自動付与する。ユーザーが「obsidianのフロントマターを整備」「フロントマターをメンテして」「obsidianのtagsを整理」「ObsidianのFMを直して」などと依頼した時にトリガーする。
---

# obsidian-frontmatter

Obsidian 保管庫内の markdown ファイルのフロントマター (YAML) をメンテナンスするスキル。

## 保管庫

```
/Users/wakodai/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian
```

このディレクトリは git 管理されている (main ブランチのみ)。

## スキルが整備するもの

1. **`created: YYYY-MM-DD HH:mm`** (必須)
   - ファイルの birth time (macOS の `stat -f %B`) から付与する
   - 既に `created` がある場合はスキップ
   - 類似キー (`created_at`、`creation_date`、`date_created`) がある場合は **キー名のみ `created` にリネーム** する (値は維持)

2. **`tags`** (必須、5 個前後が目安)
   - ファイル内容から判断して付与する
   - 正規タグ語彙は **`_templates/tags.md`** を参照する (必ず読み込んでから判断)
   - タグは全ボールトで表記揺れせず統一する

本文 (フロントマター以外) は一切変更しない。

## 作業フロー

以下を TodoWrite でタスク化して順に実行する。全ステップ必ず踏むこと。

### 1. バックアップコミット

```bash
bash ~/.claude/skills/obsidian-frontmatter/scripts/backup.sh
```

- 現在のブランチが main でなければ中断
- 未コミット変更があれば `chore: backup before frontmatter maintenance` で退避コミット
- 出力の `BACKUP_COMMIT=<hash>` を控える (以降の検証で使う)

### 2. 現状把握

```bash
python3 ~/.claude/skills/obsidian-frontmatter/scripts/list_targets.py
```

分類:
- `NO_FM` — フロントマターが無い / created 系キーが欠落
- `NEEDS_RENAME` — `created_at` 等があり `created` がない
- `NO_TAGS` — `created` はあるが `tags` がない
- `OK` — 両方揃っている

### 3. 処理対象の確認

ユーザーに **処理範囲** を確認する。デフォルトは「1 バッチ分 (約 20 ファイル)」。
ユーザーが「全部やって」と言った場合のみ全件処理するが、その場合は時間がかかる旨を伝える。
特定ディレクトリ指定 (`--under books` など) も可能。

### 4. タグ語彙の読み込み

以下を Read ツールで読み、**必ずその内容に沿ってタグを選ぶ** こと:

```
/Users/wakodai/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/_templates/tags.md
```

### 5. 各ファイルの処理

バッチ内の各ファイルについて以下を実行:

#### 5-1. created フィールドの機械的整備

```bash
python3 ~/.claude/skills/obsidian-frontmatter/scripts/fix_created.py <file.md>
```

これで `created` が揃う (リネーム or birth time から追加)。

#### 5-2. tags の判定と書き込み

1. Read ツールでファイル本文を読む (フロントマター + タイトル + 冒頭数百文字で十分)
2. 本文内容とタイトルから、`_templates/tags.md` のタグから **5 個前後** を選ぶ
   - 既存タグに該当するものがなければ、新規タグ候補をユーザーに提案する
   - ユーザーが承認したら `_templates/tags.md` に追記してから付与する
3. 書き込み:

```bash
python3 ~/.claude/skills/obsidian-frontmatter/scripts/update_tags.py <file.md> tag1 tag2 tag3 tag4 tag5
```

#### タグ選定の指針

- kebab-case / 小文字 / 単数形
- 「何についてのノートか」が一目で分かるタグを選ぶ (抽象すぎない、具体すぎない)
- AWS の個別サービス話題なら `aws` + 個別タグ (例: `aws`, `lambda`, `iam`)
- ナレッジ整理系なら分野タグ + 手法タグ (例: `auth`, `oidc`, `design-doc`)
- 既存ノートとの横串引きを意識する

### 6. 検証 (非常に重要)

バッチ処理が終わるたびに、本文が変更されていないことを検証する:

```bash
python3 ~/.claude/skills/obsidian-frontmatter/scripts/verify_body.py <BACKUP_COMMIT>
```

- `body-diff detected: 0` であることを必ず確認
- もし 0 でなかったら、そのファイルを `git checkout <BACKUP_COMMIT> -- <file>` で戻し、原因を調査 (ユーザーに報告)

### 7. バッチ末尾でコミット

verify がパスしたら、main にコミットする:

```bash
cd "/Users/wakodai/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian"
git add -A
git commit -m "chore: maintain frontmatter (N files)

- add created field (from file birth time)
- rename created_at/creation_date/date_created -> created
- assign tags from _templates/tags.md"
```

### 8. 最終報告

- 処理した件数 (カテゴリ別)
- 新規追加したタグがあれば列挙
- 残り件数と、続きをやる場合のコマンド例

## 既知の制約 / 注意

- **フロントマターの YAML 整形はしない**: 既存のインデントやクォート、キー順序はなるべく保存する。surgical な文字列置換のみ。
- **書き込み後に毎回 verify**: `verify_body.py` を忘れると、意図せず本文を壊しても気づけない。
- **iCloud 同期との衝突**: iCloud 同期中にファイルを書くと競合が起こる可能性がある。バッチを小さくして都度コミットすることで被害を最小化する。
- **`_templates/` と `_Pict/` は処理対象外**: `list_targets.py` で既に除外している。
- **タグ語彙の更新は必ずコミット前に**: `_templates/tags.md` に新規タグを追記してから付与する。

## スクリプト一覧

| スクリプト | 用途 |
|-----------|------|
| `scripts/backup.sh` | バックアップコミット (main 上) |
| `scripts/list_targets.py` | 処理対象を分類・列挙 |
| `scripts/fix_created.py` | created フィールドの追加・リネーム |
| `scripts/update_tags.py` | tags フィールドの書き込み |
| `scripts/verify_body.py` | 本文がバックアップから変わっていないか検証 |
| `scripts/tag_inventory.py` | 現在使われているタグの集計 (名寄せ材料) |
