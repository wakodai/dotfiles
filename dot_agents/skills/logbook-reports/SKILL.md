---
name: logbook-reports
description: Use when the user wants to look up their own work hours, monthly attendance summary (勤怠), per-project hours (工数/プロジェクト別), or daily work log (作業ログ) — e.g. "今月の勤怠を見せて", "4月の工数", "logbook で作業ログ", timesheet/attendance lookups. Also use when the user asks whether their hours are short/sufficient (稼働が足りている?) or wants daily hours visualized as a bar chart (グラフ/可視化), and when the user mentions the `logbook` / `logbook-bars` command or Logbook Reports.
---

# logbook-reports CLI

`logbook` は Logbook Reports API v2（`https://kurusugawa.jp/logbook-reports`）から勤務情報を取得して表示する CLI。`uv tool install` 済みで PATH 上にある（`which logbook` → `~/.local/bin/logbook`）。サブコマンドは `summary`（月次勤怠）/ `projects`（プロジェクト別工数）/ `log`（日次ログ）/ `config`。

## 認証（初回のみ／`--help` には出ない情報）

Basic 認証。解決順は **環境変数 → 設定ファイル → 対話プロンプト(getpass)**。**パスワードはコマンドライン引数では渡せない**（セキュリティ上、引数では受け付けない設計）。

- 設定ファイル: `~/.config/logbook-reports/config.toml`。`logbook config init` で雛形を生成（権限 600 を自動設定。**既存ファイルは上書き**されるので注意）→ `user` / `password` / `default_employee` を編集。
- 環境変数で上書き可: `LOGBOOK_USER` / `LOGBOOK_PASSWORD`。
- 既定 API ベース URL は内蔵。変える場合は config の `base_url`。

設定ファイル例:
```toml
user = "your_id"
password = "your_password"
default_employee = "your_id"
# base_url = "https://kurusugawa.jp/logbook-reports/api/v2"  # 任意
```

## コマンド早見表

| 目的 | コマンド |
|---|---|
| 月次勤怠サマリ | `logbook summary --month 2026-04` |
| プロジェクト別工数 | `logbook projects --month 2026-04` |
| 日次作業ログ（労働日のみ） | `logbook log --month 2026-04` |
| 特定日だけ | `logbook log --date 2026-04-01` |
| 作業詳細まで展開 | `logbook log --month 2026-04 --details` |
| JSON 出力（加工用） | 任意のコマンドに `--json` を付与 |
| 設定ファイル作成 | `logbook config init` |
| 日次を横棒グラフで可視化 | `logbook-bars 2026-07`（下記） |

## logbook-bars（日次の横棒グラフ）

**「稼働時間が足りているか」「日ごとのばらつき・偏りを見たい」「グラフで見せて」** 系の依頼はこれを使う。縦に日付、横に実労働の棒を並べ、所定 8h ラインとの過不足を 1 行ずつ表示する。

```
logbook-bars              # 当月
logbook-bars 2026-07      # 指定月
logbook-bars 2026-07 --employee ID --no-color
```

- 実体は `~/.claude/skills/logbook-reports/scripts/logbook-bars.py`（本スキル同梱）。`~/.local/bin/logbook-bars` がそこへのシンボリックリンクなので、PATH からそのまま呼べる。
- 内部で `logbook summary --json` と `logbook log --json` を呼ぶだけなので、認証は `logbook` 本体と同じ設定を使う。
- 出力: 8h までは緑 █、超過分はシアン █、8h への不足は薄い `·`、所定労働日でログの無い日は `░`（月の休暇合計が正なら「休暇と推定」、0 なら「記録なし」）。祝日・会社指定休日は `休 <名称>`、未来日は `―`。1 文字 = 20 分、`┿` が 8h ライン。
- 土日祝の稼働は所定 0h として扱うため、差分列は全量プラスになる。
- パイプ・リダイレクト時は自動で色を落とす（明示するなら `--no-color`）。

## 従業員情報（既定ユーザ wako_daisuke）

- 入社日: **2022-04-01**（在籍期間・累計計算の起点）。

## 共通オプション（全コマンド）

- 期間: `--month YYYY-MM`（既定: 当月） または `--start YYYY-MM-DD --end YYYY-MM-DD`（指定時は `--month` より優先）
- 従業員: `--employee ID`（既定: config の `default_employee`、無ければ認証ユーザ）

## 出力の読み方

- 時間は `168h 36m` 形式。差分は符号付き（例 `所定比 +0h 36m`）。
- 日数換算は **1 日 = 8 時間**。稼働は「人日」、休暇系（休暇・有給残）は「日」で併記（例 `77h 00m (9.6日)`）。
- `projects` の割合は実労働（projectcodes 合計）に対する %。
- **休暇は月次合計のみ**：`summary` の `leave_hm`/`leave_days` は月の休暇消化合計。**日単位の休暇レコードは存在しない**（休暇日を `log --date` で引くと「レコードが見つかりません」、`log` は労働日のみ表示なので休暇日は出ない）。よって「いつ有休を取ったか」を日付・時間で正確に出すことは不可（所定労働日でログ無しの日から推定しても半日休暇や記録の空きで合わない）。答えられるのは月次合計まで。
- `remaining_leave_hm`（有給残）は **どの月を指定しても現在残高を返す**スナップショット。過去月の残高推移には使えない。

## 注意・トラブル時

- 認証エラー（`エラー: 認証に失敗しました`）→ config か環境変数の user/password を確認。
- パスワードを `--password` のように引数で渡そうとしない（そのようなオプションは無い）。
- 全フラグの一次情報は `logbook <command> --help`。
