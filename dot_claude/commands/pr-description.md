---
description: ベースブランチとの差分からPR descriptionを生成する
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git branch:*)
argument-hint: [base-branch]
---

# PR Description 生成

ベースブランチ: $ARGUMENTS (指定がなければ develop, main の順に探索)

## 制約
- ghコマンドは使用しないこと。gitコマンドのみを使用すること。
- PRの発行はしないこと。descriptionのテキストだけを出力すること。

## 実行すること

1. カレントブランチ名を確認: !`git branch --show-current`
2. ベースブランチとの差分を取得: `git diff $ARGUMENTS...HEAD` (引数なしなら `git diff main...HEAD`)
3. コミット履歴を取得: `git log $ARGUMENTS..HEAD --oneline` (引数なしなら `git log main..HEAD --oneline`)
4. 上記の差分とコミット履歴を分析し、以下の構造でPR descriptionを出力。**コピペでgithubのPR descriptionに貼り付けたいので、コードブロックで出力すること**

## 出力フォーマット
```
## Summary
（変更の目的・背景を1-3行で）

## Changes
（主要な変更点を箇条書き）

## Testing
（テスト方針・確認事項）
```

PRの発行はしない。descriptionのテキストだけを出力すること。
```

使い方：
```
/pr-description         # mainとの差分で生成
/pr-description develop # developとの差分で生成
