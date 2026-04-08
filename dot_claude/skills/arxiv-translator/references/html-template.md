# HTML出力テンプレート

HTML形式で出力する場合、以下のテンプレートに従ってarXiv風スタイリングのHTMLを生成する。

## 必須要素

1. **KaTeX CDN** — 数式レンダリング用
2. **arXiv風スタイリング** — セリフフォント、適切な余白、論文らしいレイアウト
3. **レスポンシブデザイン** — モバイルでも読めるように

## テンプレート構造

```html
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{論文タイトルの日本語訳}</title>

<!-- KaTeX CSS & JS -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"
  onload="renderMathInElement(document.body, {
    delimiters: [
      {left: '$$', right: '$$', display: true},
      {left: '$', right: '$', display: false}
    ]
  });"></script>

<style>
  body {
    font-family: 'Latin Modern Roman', 'Noto Serif JP', 'Times New Roman', serif;
    color: #333; background: #fff; line-height: 1.7; font-size: 16px;
  }
  .paper { max-width: 860px; margin: 0 auto; padding: 20px 30px; }
  .banner {
    background: #f9f9f9; border-bottom: 1px solid #ddd; padding: 8px 20px;
    font-size: 0.8em; color: #666; display: flex; justify-content: space-between;
  }
  .banner a { color: #b31b1b; text-decoration: none; }
  .logo { font-weight: bold; font-size: 1.3em; color: #b31b1b; }
  .title { text-align: center; margin-bottom: 30px; }
  .title h1 { font-size: 1.8em; line-height: 1.3; margin-bottom: 15px; }
  .authors { text-align: center; font-size: 0.95em; color: #555; }
  .abstract {
    background: #fafafa; border: 1px solid #eee; border-radius: 4px;
    padding: 20px 25px; margin: 25px 0;
  }
  .abstract h2 { font-size: 1.1em; margin-bottom: 10px; }
  .abstract p { font-size: 0.95em; text-align: justify; }
  h2 { font-size: 1.4em; margin-top: 35px; margin-bottom: 15px; }
  h3 { font-size: 1.15em; margin-top: 25px; margin-bottom: 10px; }
  h4 { font-size: 1.0em; margin-top: 20px; margin-bottom: 8px; }
  p { margin-bottom: 12px; text-align: justify; }
  figure { margin: 25px 0; text-align: center; }
  figure img { max-width: 100%; height: auto; border: 1px solid #eee; border-radius: 4px; }
  figcaption { font-size: 0.9em; color: #555; margin-top: 8px; text-align: center; }
  table { width: 100%; border-collapse: collapse; font-size: 0.9em; margin: 20px 0; }
  th { background: #f5f5f5; border: 1px solid #ddd; padding: 8px 10px; text-align: center; }
  td { border: 1px solid #ddd; padding: 6px 10px; text-align: center; }
  .best { background: #d4edda; }
  .glossary table { font-size: 0.88em; }
  .bib { font-size: 0.88em; margin-bottom: 8px; padding-left: 2em; text-indent: -2em; }
  @media (max-width: 600px) { .paper { padding: 10px 15px; } .title h1 { font-size: 1.4em; } }
</style>
</head>
<body>

<div class="banner">
  <div><span class="logo">arXiv</span> &gt; {カテゴリ} &gt; arXiv:{ID}</div>
  <div>[日本語翻訳版] 原文: <a href="{原文URL}">{原文URL}</a></div>
</div>

<div class="paper">
  <div class="title">
    <h1>{論文タイトルの日本語訳}</h1>
    <div class="authors">{著者名}</div>
  </div>

  <div class="abstract">
    <h2>概要</h2>
    <p>{Abstract翻訳}</p>
  </div>

  <!-- 本文セクション -->

  <!-- 用語集 -->
  <div class="glossary">
    <h2>用語集（Glossary）</h2>
    <table>
      <tr><th>日本語</th><th>English</th><th>初出</th></tr>
      <!-- 用語エントリ -->
    </table>
  </div>

</div>
</body>
</html>
```

## 数式の記述

HTML内では `$...$`（インライン）と `$$...$$`（ブロック）を使う。KaTeXのauto-renderが
自動的にレンダリングする。特殊文字のエスケープに注意:
- `<` → そのままでOK（KaTeX内部で処理される）
- `&` → `&amp;` が必要な場合がある
- バックスラッシュはそのまま使用

## 数式番号

ブロック数式に番号を付ける場合:
```html
$$
\mathcal{L}_{\text{cfm}}(\Theta) = \mathbb{E}\left[\|\mathbf{v}_\Theta(\mathbf{a}_t, \mathbf{o}, \text{REASON}) - \mathbf{u}(\mathbf{a}_t|\mathbf{a})\|\right] \tag{1}
$$
```
