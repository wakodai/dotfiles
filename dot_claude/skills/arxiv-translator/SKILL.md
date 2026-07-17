---
name: arxiv-translator
description: >
  arXiv論文を日本語に翻訳し、3種類のMarkdown（原文・忠実訳・自然な日本語訳）を
  生成するスキル。HTML・Obsidian Canvas形式の出力にも対応する。
  PDFから本文・表・数式を正確に読み取り、HTML版から図のURLを取得する。
  自然な日本語版は原文との意味整合チェックを必須で行う。数式はLaTeX形式
  （KaTeX/MathJax互換）で記述し、末尾に用語集（glossary）を自動生成する。
  このスキルは、ユーザーがarXivのURLを提示して「日本語にして」「翻訳して」「日本語訳を
  作って」「この論文を読みたい」等と依頼したときにトリガーする。arXiv論文に限らず、
  学術論文のPDF URLを渡された場合や、「論文を日本語で読みたい」という依頼にも使用する。
---

# arXiv論文 日本語翻訳スキル

arXiv論文のURLを受け取り、以下の3種類のMarkdownを生成する（デフォルト出力）。

1. **原文Markdown**（`{title}.en.md`）— 英語原文をそのままMarkdown化したもの
2. **忠実訳Markdown**（`{title}.ja.md`）— 原文に1対1対応する忠実な日本語訳
3. **自然な日本語Markdown**（`{title}.ja-natural.md`）— 忠実訳を土台に、人間の読み手の
   読み取り負荷を下げるよう日本語らしくリライトしたもの。**原文との意味整合チェック必須**

## なぜこのワークフローなのか

arXiv論文の翻訳にはいくつかの落とし穴がある。WebFetchでHTML版を読むと長い論文は途中で
切断される。PDFは全文を正確に読めるが図のURLを持たない。このスキルでは**PDFを主軸に
読み取り、図のURLのみHTML版から補完する**ことで、両方の長所を活かす。

## ワークフロー

### Step 1: 論文の取得と読み取り

1. **URLの正規化**: ユーザーが与えたURL（abs, pdf, html いずれでも可）からarXiv IDを抽出する
   - 例: `https://arxiv.org/abs/2511.00088` → ID: `2511.00088`
   - PDF URL: `https://arxiv.org/pdf/2511.00088`
   - HTML URL: `https://arxiv.org/html/2511.00088v2`（versionは最新を使用）

2. **PDFのダウンロードと読み取り**（本文の主要ソース）:
   ```bash
   curl -sL -o /tmp/arxiv-paper.pdf "https://arxiv.org/pdf/{ARXIV_ID}"
   ```
   - まずページ数を確認:
   ```python
   from pypdf import PdfReader
   reader = PdfReader("/tmp/arxiv-paper.pdf")
   print(f"Total pages: {len(reader.pages)}")
   ```
   - pypdfが未インストールなら `pip3 install --break-system-packages pypdf` で導入
   - Readツールで20ページずつ分割して全ページ読み取り:
     - pages 1-20, 21-40, 41-60, ... と分割
   - PDFから得られるもの: **本文テキスト、表データ、数式、図キャプション、参考文献**

3. **HTML版から図のURL取得**（図の補完ソース）:
   ```bash
   # HTML版のバージョンを確認（v1, v2等）
   curl -sL -o /dev/null -w "%{url_effective}" "https://arxiv.org/html/{ARXIV_ID}"

   # figureタグからimg srcを抽出
   curl -sL "https://arxiv.org/html/{ARXIV_ID}v{N}" | grep -E 'x[0-9]+\.png|figs/' | head -30

   # 存在確認（HTTP 200チェック）
   for i in $(seq 1 20); do
     code=$(curl -sL -o /dev/null -w "%{http_code}" "https://arxiv.org/html/{ARXIV_ID}v{N}/x${i}.png")
     echo "x${i}.png -> $code"
     [ "$code" != "200" ] && break
   done
   ```
   - 一般的なパターン: `x1.png`〜`xN.png`, `figs/*.png`, `extracted/*.png`
   - figureタグのidからfigure番号とimg srcの対応を取得する

### Step 2: 論文要約の作成

翻訳本文の前に、論文の全体像を素早く把握するための構造化要約を作成する。
PDFの全ページ読み取りが完了した時点で、以下の6つの観点でまとめる。
各項目は3〜5文程度で簡潔に記述する（箇条書き可）。

```markdown
## 論文の要約

### どんなもの？
（この論文が提案するもの・やっていることを端的に説明）

### 先行研究と比べてどこがすごい？
（既存手法の限界と、本研究がそれをどう克服しているか）

### 技術や手法のキモはどこ？
（提案手法の核心的なアイデアや設計上の工夫）

### どうやって有効だと検証した？
（実験設定、使用データセット、主要な定量結果）

### 議論はある？
（著者が述べている制限事項、未解決の課題、今後の研究方向）

### 次に読むべき論文は？
（本論文が強く依存している先行研究や、関連する重要な論文を3〜5本挙げる）
```

この要約は論文全体を読んだ上で作成すること（Abstractだけから書かない）。
要約はあくまで読者のナビゲーション用であり、翻訳本文を省略する理由にはならない。

### Step 3: 原文Markdownの作成

英語原文をそのままMarkdown化する。翻訳は一切行わない。

- 原論文のセクション構造・パラグラフ構成を保持する
- 数式はLaTeX形式（後述の記法と同じ）、表はパイプテーブル、図はHTML版のURLで埋め込む
- 図キャプション・表ヘッダーも英語原文のまま
- PDFの行折り返しやハイフネーションによる単語分断は修復する（原文の再現であって
  PDFテキスト抽出結果の生ダンプではない）
- 参考文献リストも含めて全文を収録する
- フロントマターと `> **原論文**:` ブロックは日本語版と共通の形式を使う

### Step 4: 忠実訳の作成

原文に忠実に翻訳する。これは最も重要なステップであり、以下のルールを厳守する。

#### 翻訳の鉄則: 要約厳禁

翻訳で最もやりがちなミスは「要約してしまう」ことである。原文の各パラグラフに対応する
翻訳パラグラフを出力すること。パラグラフを統合したり省略したりしない。原文に5文あるなら
翻訳にも5文（同等の情報量の文）があるべきである。

#### 専門用語の扱い

- **初出時**: 日本語訳（英語原語）の形式で記載
  - 例: `強化学習（reinforcement learning; RL）`
  - 例: `閉ループシミュレーション（closed-loop simulation）`
- **2回目以降**: 日本語のみ、または定義済み略語を使用
  - 例: `強化学習` または `RL`
- **そのまま残すもの**: モデル名（GPT-4, Cosmos-Reason等）、データセット名（nuScenes等）、
  ベンチマーク名（LingoQA等）、人名、URL

#### 数式の記述

数式はLaTeX形式で記述する（KaTeX/MathJax互換）:

- インライン数式: `$...$` で囲む
  - 例: `エゴ車両の座標 $(x^i, y^i, \theta^i_{\text{yaw}})$`
- ブロック数式: `$$...$$` で囲む
  - 例:
    ```
    $$
    \mathcal{L}_{\text{SFT}}(\theta) = -\mathbb{E}_{(\mathbf{o}, \text{REASON}, \mathbf{a}) \sim \mathcal{D}_{\text{CoC}}} \left[ \log \pi_\theta(\text{REASON}, \mathbf{a} \mid \mathbf{o}) \right]
    $$
    ```
- 数式番号がある場合は末尾に `\tag{N}` を付与

#### 図の埋め込み

```markdown
![図N: キャプションの日本語訳](https://arxiv.org/html/{ARXIV_ID}v{N}/x{M}.png)

**図N**: キャプションの日本語訳。（図中のテキストは原文のままでよい）
```

#### 表の記述

Markdownのパイプテーブルで完全再現する。数値は原文のまま保持。ヘッダーは日本語訳する。

### Step 5: 自然な日本語版の作成

忠実訳（Step 4）を土台に、人間の読み手の読み取り負荷を下げる日本語にリライトする。
新規に翻訳し直すのではなく、忠実訳の各パラグラフを書き直す。

#### リライトの方針

- **翻訳調の解消**: 以下のような直訳のクセを日本語らしい表現に直す
  - 無生物主語の構文 → 「本手法により〜できる」「〜という結果になった」等に組み替える
  - 受動態の多用 → 能動態や「〜されている」以外の自然な形に
  - 「〜することができる」→「〜できる」、「〜を行う」→ 動詞一語に
  - 関係代名詞の入れ子をそのまま訳した長い連体修飾 → 文を分割して解消
- **文の分割は可**: 原文の1文が長い場合、意味を保ったまま2〜3文に分けてよい
- **語順の組み替えは可**: 日本語として読みやすい語順に変えてよい
- **読者への補助**: 指示語が遠くて追いにくい場合、指すものを明示してよい
  （例: 「これ」→「この損失関数」）

#### リライトの禁止事項

- **情報の削除・要約**: 忠実訳にある情報を落とさない。文を分割しても情報量は保つ
- **情報の追加・解釈**: 原文にない説明・意見・推測を足さない
- **意味の変更**: 断定と推量の区別（may/might/suggest等のニュアンス）、
  数値、比較の方向、因果関係を変えない
- **パラグラフ対応の破壊**: パラグラフ単位の対応は維持する（Step 6のチェックで
  原文と突き合わせるため）。パラグラフの統合・分割・並べ替えはしない
- **訳語の変更**: 専門用語は忠実訳と同じ訳語を使う（用語集との整合を保つ）。
  初出時の「日本語訳（英語原語）」併記も維持する
- **数式・表・図の変更**: 忠実訳からそのままコピーする

### Step 6: 意味整合チェック（自然な日本語版は必須）

自然な日本語版は「読みやすさを優先しすぎて原文と意味がずれる」リスクがあるため、
生成後に必ずチェックを行う。**リライトした本人（同一コンテキスト）ではなく、
Agentツールで独立したチェック用エージェントを立てて検証する。**

#### チェック手順

1. チェック用エージェントに以下を渡す:
   - 原文Markdown（または原文テキスト）
   - 自然な日本語版Markdown
   - チェック観点（下記）
2. **パラグラフ単位で突き合わせ**、以下を検出させる:
   - **欠落**: 原文にあって訳文にない情報（文・句・限定条件・数値）
   - **追加**: 原文にない情報・解釈の混入
   - **意味の反転・変質**: 比較の方向、因果、否定、断定/推量の強さのずれ
   - **数値・固有名詞の不一致**: 数値、モデル名、データセット名、引用番号
3. エージェントには問題箇所を構造化して報告させる:
   ```
   - セクション / パラグラフ位置
   - 原文の該当箇所（引用）
   - 訳文の該当箇所（引用）
   - 問題の種類（欠落 / 追加 / 意味変質 / 数値不一致）
   - 修正案
   ```
4. 報告された問題を修正し、**修正箇所についてのみ再チェック**する
5. 問題ゼロになるまで繰り返す（通常1〜2回で収束する。3回を超える場合は
   忠実訳側に問題がないかを疑う）

論文が長い場合はセクション単位でチェック用エージェントを分割し、並列に検証してよい。

### Step 7: 出力生成

デフォルトでは3種類のMarkdownをすべて出力する。ユーザーが特定の版だけを求めた場合
（例：「自然な日本語版だけでいい」）はそれに従う。HTML・Obsidian Canvas形式は
ユーザーが指定した場合のみ追加で生成する。

#### 生成の流れと並列処理

3種類のMarkdownには依存関係がある（自然版は忠実訳から作り、チェックは原文版を使う）
ため、以下の順序で生成する。原文版と忠実訳は独立なのでAgentツールで並列生成してよい。

```
Step 1-2: 共通処理（逐次）
  PDF読み取り → 図URL取得 → 要約作成
       ↓
原文版・忠実訳（並列可）
  ├── Agent A: 原文Markdown（{title}.en.md）
  └── Agent B: 忠実訳Markdown（翻訳 + 用語集 + {title}.ja.md）
       ↓
自然な日本語版（忠実訳の完成後）
  Agent C: 忠実訳をリライト（{title}.ja-natural.md）
       ↓
意味整合チェック（原文版と自然版が揃ってから）
  Agent D: 原文と突き合わせて検証 → 問題があれば修正して再チェック
       ↓
（ユーザー指定時のみ）HTML版・Canvas版を並列生成
```

各Agentへのpromptには以下を含める：
- 論文のPDF内容（読み取り済みテキスト）または土台となるMarkdown
- 図のURL一覧
- 要約テキスト
- 該当ステップのルール（翻訳の鉄則、リライトの方針と禁止事項、チェック観点）
- 出力先ファイルパス

論文が短い場合（目安: 10ページ以下）はAgentを使わず直接生成してよい。
ただし意味整合チェックだけは必ず独立したAgentで行う。

#### ファイル名の規則

出力ファイル名は**原文の論文タイトル**をベースにする。
ファイル名にふさわしくない文字（スペース、コロン、スラッシュ等）はアンダースコアに置換する。

**ディレクトリ構成**: ファイル名（拡張子なし）と同名のディレクトリを作成し、
その中に出力ファイルを配置する。

- 例: "Alpamayo-R1: Bridging Reasoning and Action Prediction for Generalizable Autonomous Driving in the Long Tail"
  → ディレクトリ: `Alpamayo-R1_Bridging_Reasoning_and_Action_Prediction_for_Generalizable_Autonomous_Driving_in_the_Long_Tail/`
  → Markdown: `{dir}/Alpamayo-R1_Bridging_Reasoning_and_Action_Prediction_for_Generalizable_Autonomous_Driving_in_the_Long_Tail.md`
  → HTML: `{dir}/Alpamayo-R1_Bridging_Reasoning_and_Action_Prediction_for_Generalizable_Autonomous_Driving_in_the_Long_Tail.html`
  → Canvas: `{dir}/Alpamayo-R1_Bridging_Reasoning_and_Action_Prediction_for_Generalizable_Autonomous_Driving_in_the_Long_Tail.canvas`
- 複数形式を出力する場合も同一ディレクトリにまとめる
- ディレクトリが存在しない場合は `mkdir -p` で作成する

#### 論文タイトルの表記

論文タイトルは原文（英語）と日本語訳を併記する：

```markdown
# Alpamayo-R1: Bridging Reasoning and Action Prediction for Generalizable Autonomous Driving in the Long Tail
# Alpamayo-R1: ロングテールにおける汎化可能な自動運転のための推論と行動予測の橋渡し
```

#### Markdown形式（デフォルト）

構成:
```markdown
---
created: YYYY-MM-DD HH:mm
tags:
  - 論文
---

# {原文タイトル（英語）}
# {日本語タイトル}

> **原論文**: [arXiv:{ID}]({URL})
> **著者**: 著者名
> **所属**: 所属機関

---

## 論文の要約

### どんなもの？
...
### 先行研究と比べてどこがすごい？
...
### 技術や手法のキモはどこ？
...
### どうやって有効だと検証した？
...
### 議論はある？
...
### 次に読むべき論文は？
...

---

## 概要

（Abstract全文の翻訳）

---

## 1. はじめに

（以下、原論文のセクション構造に準拠した忠実な翻訳）

...

---

## 用語集（Glossary）

| 日本語 | English | 初出セクション |
|--------|---------|--------------|
| 強化学習 | Reinforcement Learning (RL) | 概要 |
| 閉ループシミュレーション | Closed-loop Simulation | Sec. 6 |
| ... | ... | ... |
```

#### HTML形式

`references/html-template.md` を参照して、arXiv風スタイリングとKaTeX CDNを含む
HTMLを生成する。

#### Obsidian Canvas形式

`references/obsidian-canvas.md` を参照して、セクションごとにノードを配置した
.canvas ファイルを生成する。

### Step 5: 用語集（Glossary）の自動生成

翻訳完了後、文書中で「日本語（英語）」形式で記載した全専門用語を収集し、末尾に
用語集テーブルとして追加する。以下の列を含む:

| 日本語 | English | 初出セクション |
|--------|---------|--------------|

30〜60語程度を目安とし、あまりに一般的な用語（例: 「モデル」「データ」）は除外する。

### Step 6: 検証（オプション）

ユーザーが確認を求めた場合、またはHTML出力の場合、Playwrightでブラウザレンダリングを
確認する:

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1200, "height": 900})
    page.goto(f"file://{output_path}")
    page.wait_for_load_state('networkidle')
    page.screenshot(path='/tmp/translation-preview.png')
    # 図が表示されているか確認
    images = page.locator('img')
    print(f"Images found: {images.count()}")
    browser.close()
```

## トラブルシューティング

- **pypdfが入っていない**: `pip3 install --break-system-packages pypdf`
- **Playwrightが入っていない**: `pip3 install --break-system-packages playwright && python3 -m playwright install chromium`
- **HTML版が存在しない（古い論文）**: PDFのみで進行し、図はプレースホルダーで記載
- **図のURLが取得できない**: `curl -sI` でリダイレクト先を確認。バージョン番号（v1, v2等）を調整
- **PDFのReadで画像が多くテキストが少ない**: pdfplumberでテキスト抽出を試みる
