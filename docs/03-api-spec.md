# AI-UCDS LLM WebApp API 仕様書

## 1. API 仕様の基本方針

本リポジトリの `gateway` は Nginx ベースの入口であり、各アプリは内部的に独自の FastAPI API を持つ。統合システムとしては、各アプリサービスが `/word-vector/`, `/next-token/` などの URL パスに配置される想定である。

## 2. 入口 API

### 2.1 ルート画面

- Method: GET
- Path: `/`
- 説明: 4 種類の可視化アプリへのリンクを表示する入口ページ

#### レスポンス
- `text/html`
- 画面上に以下のリンクを表示
  - Word Vector Visualizer
  - Next Token Predictor
  - Attention Visualizer
  - Tokenizer Visualizer

## 3. 各サービスの公開ルーティング

| Public Path | Internal Service | 説明 |
|---|---|---|
| `/word-vector/` | `word-vector` | 単語ベクトル可視化 |
| `/next-token/` | `next-token` | 次トークン生成 |
| `/attention/` | `attention` | Attention 可視化 |
| `/tokenizer/` | `tokenizer` | トークナイズ可視化 |

## 4. 個別アプリ API

### 4.1 word-vector

#### ヘルスチェック
- Method: GET
- Path: `/health`
- 返却値:

```json
{"status": "ok"}
```

#### 単語解析
- Method: POST
- Path: `/analyze`
- Content-Type: `application/json`

##### Request Body

```json
{
  "words": ["東京", "AI", "言語モデル"],
  "reduction": "pca",
  "metric": "euclidean",
  "x_range": 1.0
}
```

##### Request Schema

```json
{
  "words": ["string"],
  "reduction": "pca | umap",
  "metric": "euclidean | cosine",
  "x_range": 1.0
}
```

##### Response Body

```json
{
  "points": [
    {"word": "東京", "x": 0.12, "y": -0.34},
    {"word": "AI", "x": 0.54, "y": 0.22}
  ],
  "matrix_labels": ["東京", "AI", "言語モデル"],
  "matrix_values": [[1.0, 0.3, 0.2], [0.3, 1.0, 0.7]],
  "axis_min": -1.0,
  "axis_max": 1.0,
  "reduction": "pca",
  "metric": "euclidean"
}
```

##### 処理内容
- `SentenceTransformer` により単語ベクトルを取得
- `PCA` または `UMAP` で 2D 投影
- 類似度マトリクスを生成
- 正規化して `[-1, 1]` 範囲に落とし込む

---

### 4.2 next-token

#### ヘルスチェック
- Method: GET
- Path: `/api/health`

##### レスポンス例

```json
{
  "status": "ok",
  "model_id": "sbintuitions/sarashina2.2-0.5b",
  "device": "cpu"
}
```

#### 次トークン生成
- Method: POST
- Path: `/api/generate`
- Content-Type: `application/json`

##### Request Body

```json
{
  "input_text": "日本語の文章を入力します。"
}
```

##### Response Body

```json
{
  "input_text": "日本語の文章を入力します。",
  "generated_text": "生成された文章",
  "trace": [
    {
      "step_number": 1,
      "current_text": "日本語の文章を入力します。",
      "selected_token_id": 123,
      "selected_token": "生成",
      "candidates": [
        {
          "token_id": 123,
          "token": "生成",
          "probability": 0.82,
          "selected": true
        }
      ]
    }
  ]
}
```

##### 処理内容
- モデルをロード
- 入力テキストを tokenizer でエンコード
- `generate()` により生成
- 各ステップの候補トークンと確率を trace として返却

---

### 4.3 attention

#### ヘルスチェック
- Method: GET
- Path: `/health`

##### レスポンス例

```json
{"status": "ok"}
```

#### attention 計算
- Method: POST
- Path: `/api/analyze`

##### Request Body

```json
{
  "text": "日本語の入力文です。"
}
```

##### Response Body

```json
{
  "tokens": ["[CLS]", "日本", "語", "の", "入力", "文", "です", "。", "[SEP]"],
  "attention": [[0.12, 0.05, ...], [ ... ]],
  "shape": [8, 8],
  "averaged_over": "layers_and_heads_without_cls_sep"
}
```

##### 処理内容
- Hugging Face モデルの `output_attentions=True`
- 全 layer / 全 head の attention を平均
- `[CLS]` と `[SEP]` を除外して表示
- 可視化専用の行列に変換

---

### 4.4 tokenizer

#### ヘルスチェック
- Method: GET
- Path: `/health`

##### レスポンス例

```json
{"status": "ok"}
```

#### 分析
- Method: POST
- Path: `/analyze`

##### Request Body

```json
{
  "text": "日本語の文章を入力します。"
}
```

##### Response Body

```json
{
  "surface_joined": "日本/語/の/文章/を/入力/し/ます/。",
  "tokens": [
    {"surface": "日本語", "pos_major": "名詞", "is_symbol": false},
    {"surface": "の", "pos_major": "助詞", "is_symbol": false}
  ],
  "bert_subwords": ["[CLS]", "日", "本", "語", "の", "文", "章", "を", "入力", "し", "ま", "す", "。", "[SEP]"],
  "bert_token_ids": [2, 123, 456, ...]
}
```

##### 処理内容
- Sudachi による形態素解析
- 品詞情報の付与
- BERT tokenizer による subword 変換

## 5. API の共通ルール

- すべての API は FastAPI で実装
- JSON 形式を用いる
- CORS は localhost 環境向けに許可
- 例外時には `HTTPException` でエラー応答を返す

## 6. エラー応答例

```json
{
  "detail": "text must not be empty"
}
```

または

```json
{
  "detail": "Model is not loaded. Check MODEL_NAME."
}
```

## 7. 運用上の留意点

- next-token は重いモデルロード待ちが発生する
- backend API は各コンテナ内で `uvicorn` で起動
- gateway 経由では URL パスがそのままバックエンドへ転送される
- ルート画面は各アプリへのハイパーリンクで構成されている

## 8. まとめ

本システムの API は、各可視化アプリごとに独立した FastAPI ベースの API を持ちつつ、gateway 側で URL パスを統合する形で構成されている。これにより、UI 側では 1 つの入口から各機能へ自然に遷移できる。

