---
name: confluence-cli
description: Use when reading, updating, or appending to Confluence pages/blogs from the command line on this machine — whenever the request names a Confluence page ID, mentions the `confluence` CLI (kci-confluence-cli), or asks to write/fetch Confluence content. Covers auth env vars, the non-interactive-shell gotcha, and the get→edit→update pattern.
---

# confluence-cli

このマシンに `uv tool` で導入済みの `confluence` コマンド（PyPI: `kci-confluence-cli`）で Confluence v6.15.7 を操作するためのリファレンス。Confluence ページ ID への読み書き依頼が来たら、毎回 `--help` を調べ直さずこのスキルを参照する。

## 認証（最重要の落とし穴）

認証は3つの環境変数で行う。通常のターミナル（インタラクティブ zsh）では `~/.zshrc` で設定済みなので素直に動く。

**しかしエージェントが Bash ツールで実行する非対話シェルは `.zshrc` を読まない。** 環境変数が無いと `ConfluenceのURLを入力してください` と対話プロンプトが出て `EOFError` で落ちる。**Bash ツールから実行するときは必ず環境変数をインライン付与する**（パスワードは macOS Keychain から展開、平文はコマンド行に出さない）:

```bash
export CONFLUENCE_BASE_URL="https://kurusugawa.jp/confluence"
export CONFLUENCE_USER_NAME="wako_daisuke"
export CONFLUENCE_USER_PASSWORD="$(security find-generic-password -a "$USER" -s confluence_password -w 2>/dev/null)"
# 以降この同じ Bash 呼び出し内で confluence ... を実行する
```

## コマンド早見表

| やること | コマンド |
| --- | --- |
| サブコマンド一覧 | `confluence -h` / `confluence page -h` |
| 本文を取得（標準出力） | `confluence page get_body -p PAGE_ID --pretty` |
| 本文をファイルに保存 | `confluence page get_body -p PAGE_ID -o body.xml` |
| 描画後HTMLで確認 | `confluence page get_body -p PAGE_ID --representation view --pretty` |
| ページ更新 | `confluence page update -p PAGE_ID --xml_file body.xml --comment "..." --yes` |

- `get_body` の `--representation` 既定は `storage`（編集用の XHTML）。確認用に描画したいときは `view`。
- `update` の `--yes` は確認プロンプトを自動 yes（非対話実行に必須）。`--comment` で更新履歴コメントを残す。
- トップレベルに `attachment` / `content` / `local` サブコマンドもある。詳細は各 `-h`。

## 追記の鉄則：update は本文を丸ごと置換する

`page update --xml_file` は**ファイルの内容でページ本文を完全に上書き**する。追記・部分編集でも既存内容は保持されない。よって**追記は必ず次の順序**で行う:

1. `confluence page get_body -p PAGE_ID -o current.xml` で現本文（storage 形式）を取得
2. `current.xml` を編集して追記（既存の `<div>...</div>` 内に新セクションを足す）
3. `confluence page update -p PAGE_ID --xml_file current.xml --comment "..." --yes` で書き戻す
4. `get_body --representation view` で反映を確認

本文は **Confluence storage フォーマット（XHTML）**。`<h2>` `<ul><li>` `<p>` `<strong>` `<a href="...">` 等が使える。`&` は `&amp;` にエスケープする。

## よくある失敗

| 失敗 | 対処 |
| --- | --- |
| `EOFError` / URL 入力プロンプトで停止 | 非対話シェルに環境変数を渡していない。上記の inline export を付ける |
| 更新したら既存内容が消えた | `update` は全置換。先に `get_body` して編集してから書き戻す |
| 更新がプロンプト待ちで止まる | `--yes` を付ける |
| リンク内の `&` でXMLが壊れる | `&amp;` にエスケープ |
