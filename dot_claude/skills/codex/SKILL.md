---
name: codex
description: |
  Codex CLI（OpenAI）を使用してコードや文言について相談・レビューを行う。
  トリガー: "codex", "codexと相談", "codexに聞いて", "コードレビュー", "レビューして"
  使用場面: (1) 文言・メッセージの検討、(2) コードレビュー、(3) 設計の相談、(4) バグ調査、(5) 解消困難な問題の調査、(6) 文体・ペルソナのバリエーション生成（モデル系統を多様化する目的）
---

# Codex

Codex CLIを使用してコードレビュー・分析を実行するスキル。

## 実行コマンド

```
codex exec --sandbox read-only --skip-git-repo-check --cd <project_directory> "<request>" </dev/null
```

## プロンプトのルール

**重要**: codexに渡すリクエストには、以下の指示を必ず含めること：

> 「確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。」

## パラメータ

| パラメータ | 説明 |
|-----------|------|
| `--sandbox read-only` | 読み取り専用サンドボックス（安全な分析用） |
| `--skip-git-repo-check` | 対象ディレクトリが git リポジトリでない場合に必須。これがないと trust チェックで失敗 |
| `--cd <dir>` | 対象プロジェクトのディレクトリ |
| `"<request>"` | 依頼内容（日本語可） |
| `</dev/null` | **必須**。非インタラクティブ呼び出しで stdin を閉じないと、Codex はプロンプト受領後も追加入力を待ち続けてハングする |

> 注: 旧バージョンで使われていた `--full-auto` は deprecated。`--sandbox read-only` 指定下では不要。

## 使用例

**注意**: 各例では末尾に「確認不要、具体的な提案まで出力」の指示を含めている。

### コードレビュー
```
codex exec --sandbox read-only --skip-git-repo-check --cd /path/to/project "このプロジェクトのコードをレビューして、改善点を指摘してください。確認や質問は不要です。具体的な修正案とコード例まで自主的に出力してください。" </dev/null
```

### バグ調査
```
codex exec --sandbox read-only --skip-git-repo-check --cd /path/to/project "認証処理でエラーが発生する原因を調査してください。確認や質問は不要です。原因の特定と具体的な修正案まで自主的に出力してください。" </dev/null
```

### アーキテクチャ分析
```
codex exec --sandbox read-only --skip-git-repo-check --cd /path/to/project "このプロジェクトのアーキテクチャを分析して説明してください。確認や質問は不要です。改善提案まで自主的に出力してください。" </dev/null
```

### リファクタリング提案
```
codex exec --sandbox read-only --skip-git-repo-check --cd /path/to/project "技術的負債を特定し、リファクタリング計画を提案してください。確認や質問は不要です。具体的なコード例まで自主的に出力してください。" </dev/null
```

### デザイン相談（UI/UX）
```
codex exec --sandbox read-only --skip-git-repo-check --cd /path/to/project "あなたは世界トップクラスのUIデザイナーです。以下の観点からこのプロジェクトのUIを評価してください: (1) 視覚的階層構造とタイポグラフィ、(2) 余白・スペーシングのリズム、(3) カラーパレットのコントラストとアクセシビリティ、(4) インタラクションパターンの一貫性、(5) ユーザーの認知負荷の軽減。確認や質問は不要です。具体的な改善案をコード例付きで提示してください。" </dev/null
```

```
codex exec --sandbox read-only --skip-git-repo-check --cd /path/to/project "UXリサーチャー兼デザイナーとして、このフォームのユーザビリティを分析してください。Nielsen の10ヒューリスティクスに基づき、(1) エラー防止の仕組み、(2) ユーザーの制御と自由度、(3) 一貫性と標準、(4) 認識vs記憶の負荷、(5) 柔軟性と効率性を評価してください。確認や質問は不要です。改善したTailwind CSSコードまで自主的に提示してください。" </dev/null
```

### ペルソナ発話の生成（モデル系統の多様化目的）
複数モデル（Claude / Codex）でペルソナを演じ分けたい場面で、Codex 側に役を割り当てる用途。長いプロンプトは heredoc で渡す：

```
codex exec --sandbox read-only --skip-git-repo-check --cd /path/to/project "$(cat <<'EOF'
あなたは [役柄の詳細]。
[状況設定]
[今回のタスク：観察を語る / 問いを提示する など]
[制約：規範禁止 / 字数 / 一人称 / 婉曲化禁止 など]
確認や質問は不要です。発言内容を直接出力してください。
EOF
)" </dev/null
```

## 実行手順

1. ユーザーから依頼内容を受け取る
2. 対象プロジェクトのディレクトリを特定する（現在のワーキングディレクトリまたはユーザー指定）
3. **プロンプトを作成する際、末尾に「確認や質問は不要です。具体的な提案まで自主的に出力してください。」を必ず追加する**
4. 上記コマンド形式で Codex を実行（`</dev/null` の付け忘れに注意）
5. 結果をユーザーに報告

## トラブルシューティング

過去にハマった3つの罠（再度同じ罠にかからないために記録）：

| 症状 | 原因 | 対処 |
|------|------|------|
| 出力ファイルに `Reading additional input from stdin...` と書かれたまま無限に応答が返らない | 非インタラクティブ実行で Codex がプロンプト受領後も stdin を読みに行ってハング | コマンド末尾に `</dev/null` を付けて stdin を明示的に閉じる |
| `Not inside a trusted directory and --skip-git-repo-check was not specified.` で即座に失敗 | `--cd` で指定したディレクトリが git リポジトリでない | `--skip-git-repo-check` を追加する |
| `warning: --full-auto is deprecated; use --sandbox workspace-write instead` の警告が出る | `--full-auto` は廃止予定 | `--full-auto` を削除する。`--sandbox read-only` だけで十分 |

これらは Claude Code の Bash ツール経由で Codex を呼び出すときに特に発生しやすい（非 TTY 環境のため）。
