# AI-UCDS LLM WebApp ユースケース・画面仕様

## 1. 対象と前提

本書は、確認できた各アプリの React 画面実装に基づくユースケース仕様である。統合入口は `gateway/index.html`、各アプリ画面は個別 Git submodule に置かれる。

## 2. アクター

- 利用者: 入力を行い、可視化結果を確認する。
- システム: gateway、各フロントエンド、FastAPI、各モデル/解析ライブラリ。

## 3. ユースケース一覧

| ID | ユースケース | 対象 |
|---|---|---|
| UC-01 | 統合ポータルを開き、可視化アプリを選択する | Gateway |
| UC-02 | 複数単語のベクトル配置と距離/類似度を見る | Word Vector |
| UC-03 | 入力文から続きの文章と予測候補を確認する | Next Token |
| UC-04 | 入力文の Attention 関係を線図・heatmapで確認する | Attention |
| UC-05 | 日本語文の形態素とBERT subwordを確認する | Tokenizer |

## 4. ユースケース詳細

### UC-01: 統合ポータルから選択

1. 利用者が `/` を開く。
2. gateway が `gateway/index.html` を返す。
3. 利用者が4つのリンクのいずれかを選ぶ。
4. gateway が対応するコンテナへ転送する。

代替: `/word-vector` 等の末尾 `/` がないURLは、gateway が末尾 `/` 付きへ redirect する。

### UC-02: Word Vector 可視化

1. 利用者が単語を1件ずつ入力して追加、または複数単語を改行/カンマ区切りで入力する。
2. 画面は単語数を最大10件まで追加する。
3. 利用者が PCA/UMAP、Euclidean/Cosine、x range を選ぶ。
4. 「実行」を押すと `analyzeWords` が `/analyze` に JSON POST する。
5. 成功時に scatter plot と単語間 matrix を表示する。
6. API エラー時は detail または既定エラーを画面表示する。

入力スキーマでは単語は2〜10件。UI上は1件でも追加できるため、1件のまま実行した場合は backend validation error となり得る。

### UC-03: Next Token 生成

1. 初期例文がテキスト欄に表示される。
2. 利用者が入力文を編集し、「生成」を押す。
3. 空白のみの入力は画面側で拒否される。
4. Frontend が `POST /api/generate` に `{input_text}` を送信する。
5. Backend が生成文と各ステップの候補token、ID、確率、選択状態を返す。
6. OutputPanel が結果を表示する。
7. 失敗時にメッセージを表示し、loading状態を解除する。

### UC-04: Attention 可視化

1. 入力文が表示され、最大1000文字まで入力する。
2. 「実行」を押す。
3. frontend が `analyzeText` を呼び、backend に POST する。
4. backend が tokenizer とモデルを使って attention matrix を計算する。
5. 結果に token があればトークン列、線図、heatmap を表示する。
6. 利用者がトークンを選ぶと、選択トークンの関係を更新する。
7. 空入力、文字数超過、モデル未ロード等ではエラーを表示する。

### UC-05: Tokenizer 可視化

1. 利用者が日本語テキストを入力する。
2. 「実行」を押す。
3. 空入力は画面側で拒否される。
4. Frontend が `POST /analyze` に `{text}` を送信する。
5. Backend が Sudachi 形態素解析と BERT tokenizer を実行する。
6. 形態素一覧と表層形の連結表示を画面へ返す。
7. token chip とエラー状態を表示する。

## 5. 画面仕様

| 画面 | 主な入力 | 主な出力 | 状態 |
|---|---|---|---|
| 統合入口 | アプリリンク選択 | 4機能へのリンク | 通常 |
| Word Vector | 単語、reduction、metric、x range | 点群チャート、行列テーブル、エラー | 入力中/実行/成功/失敗 |
| Next Token | 入力文 | 生成文、step trace、候補 | 入力中/loading/成功/失敗 |
| Attention | 入力文 | token列、attention arc、heatmap | 入力中/loading/成功/失敗 |
| Tokenizer | 入力テキスト | 形態素、品詞、subword結果 | 入力中/loading/成功/失敗 |

## 6. 画面上の制約

- Word Vector: UIは単語を最大10件まで追加。backend request schema は2〜10単語。
- Attention: `MAX_CHARS=1000`、空白のみの入力は不可。
- Tokenizer: 空白のみの入力は不可。
- Next Token: 空白のみの入力は不可。生成上限等は backend/Compose の設定に依存する。

## 7. ユーザー向けエラー

- Word Vector: backend の `detail` があれば表示し、なければ「実行に失敗しました。」
- Next Token: 入力空チェック、APIエラー、生成失敗を表示。
- Attention: 入力空・文字数上限・モデル未ロード等を表示。
- Tokenizer: 入力空・解析失敗・不明なエラーを表示。

## 8. 画面改善検討事項

- gateway の入口ページは4アプリのリンクのみで、各機能の説明は限定的。
- Word Vector はUIで1単語の実行を防いでいないが、backend は最低2単語を要求する。
- 各画面に共通のホーム/戻るナビゲーションが必要か検討する。
- loading中の連打防止、通信タイムアウト、アクセシビリティ、モバイル表示を受入条件として定義する。
