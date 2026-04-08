# Obsidian Canvas出力形式

Obsidian Canvas形式（.canvas）で出力する場合のガイド。

## Canvas JSONフォーマット

Obsidian Canvasは `.canvas` 拡張子のJSONファイルで、ノードとエッジで構成される。

```json
{
  "nodes": [
    {
      "id": "node-1",
      "type": "text",
      "x": 0,
      "y": 0,
      "width": 800,
      "height": 400,
      "text": "# タイトル\n\nMarkdown本文..."
    },
    {
      "id": "node-2",
      "type": "text",
      "x": 0,
      "y": 500,
      "width": 800,
      "height": 600,
      "text": "## セクション1\n\n..."
    },
    {
      "id": "node-fig1",
      "type": "link",
      "url": "https://arxiv.org/html/.../x1.png",
      "x": 900,
      "y": 0,
      "width": 500,
      "height": 300
    }
  ],
  "edges": [
    {
      "id": "edge-1",
      "fromNode": "node-1",
      "fromSide": "bottom",
      "toNode": "node-2",
      "toSide": "top"
    }
  ]
}
```

## レイアウト戦略

セクションごとにノードを縦に配列し、対応する図を右側に配置する：

```
[タイトル・概要]     [図1: アーキテクチャ]
       |
[1. はじめに]
       |
[2. 関連研究]
       |
[3. 手法]           [図2] [図3]
       |
[4. データセット]    [図4]
       |
[5. 訓練戦略]       [図5] [図6]
       |
[6. 実験]           [図7-14] [表6-14]
       |
[7. 結論]
       |
[用語集]
```

## ノードサイズの目安

- タイトル・概要ノード: width=800, height=500
- セクションノード: width=800, height=セクション長に応じて400-1200
- 図ノード: width=500, height=300
- 表ノード: width=600, height=表行数×30+100

## 各ノードの内容

ノード内のtextフィールドにはMarkdown記法が使える。数式も `$...$` と `$$...$$` が
Obsidianで対応している。翻訳ルールはMarkdown出力と同一。

## 注意点

- ノードが重ならないようx, y座標を適切に設定する
- edgeでセクション間の流れを表現する
- 図のノードは `type: "link"` でURL直接参照（Obsidianが画像をプレビューする）
- テキストが長すぎるノードは読みにくいので、サブセクション単位で分割することも検討する
