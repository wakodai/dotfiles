---
description: dotfiles（chezmoi管理）の状態を確認し、未同期の変更があれば同期する。「dotfilesの管理状況をチェックして」「dotfilesの状態を確認」「chezmoi の状態を見て」「dotfiles同期して」などの発言でトリガーする。
user_invocable: true
---

# dotfiles管理状況チェック

chezmoiで管理されているdotfilesの状態を確認し、必要に応じて同期を行う。

## 手順

### 1. chezmoi の存在確認

```bash
command -v chezmoi
```

chezmoi がインストールされていない場合は、その旨を報告して終了する。

### 2. 管理対象の変更差分を確認

```bash
chezmoi diff
```

- 出力がなければ「管理対象ファイルに未同期の変更はありません」と報告
- 出力があれば、差分内容をユーザーに見せる

### 3. chezmoi の管理状態を表示

```bash
chezmoi status
```

各ファイルの状態（追加/変更/削除）を表示する。

### 4. chezmoi ソースリポジトリの git 状態を確認

```bash
chezmoi git -- status
chezmoi git -- log --oneline -5
```

- uncommitted な変更がないか
- unpushed なコミットがないか
- 直近のコミット履歴

### 5. 未同期の変更がある場合

ユーザーに以下の選択肢を提示する：

- **`chezmoi re-add`**: ローカルの変更を chezmoi ソースに反映（autoCommit + autoPush が有効なので自動的に GitHub にも push される）
- **`chezmoi apply`**: chezmoi ソースの内容をローカルに適用（ソース側が正しい場合）
- **`chezmoi diff <ファイルパス>`**: 特定ファイルの差分を詳しく確認

ユーザーの指示に従ってアクションを実行する。

### 6. 管理対象一覧の表示（求められた場合）

```bash
chezmoi managed
```

現在 chezmoi で管理されている全ファイルの一覧を表示する。
