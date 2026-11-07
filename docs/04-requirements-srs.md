# AI-UCDS LLM WebApp 要件定義書（SRS）

- 文書版: 1.0（実装確認ベース）
- 対象リポジトリ: `ryk765/AI-UCDS-llm-webapp`
- 対象範囲: 統合Webアプリ、gateway、共通コンテナ基盤、4つの可視化アプリ
- 根拠: リポジトリの README、Compose、Nginx、共通 Dockerfile、Git submodule と各アプリの確認可能な実装

> 本書は現行コードから読み取れる要件を整理したものです。実装上の制約・不整合も明記しています。未実装の要求を既存機能として扱わないでください。

## 1. 目的と背景

4種類のLLM可視化アプリを同一の入口から利用できるようにし、Docker Compose でまとめて起動・配備する。アプリ本体は Git submodule で分離し、統合リポジトリは共通実行基盤、サービス構成、入口ルーティングを担当する。

## 2. 利用者とアクター

| アクター | 目的 |
|---|---|
| 利用者 | 入口ページから可視化アプリを選び、入力して結果を確認する |
| 開発者 | 各アプリを個別に開発し、Compose で統合して動作確認する |
| 運用担当者 | Compose 構成を Azure Web App for Containers 等に配備する |

認証・利用者管理・権限管理は、確認した構成には定義されていない。

## 3. スコープ

### 対象
- 入口ページと URL パスによるアプリ切替
- gateway から各アプリコンテナへの HTTP ルーティング
- アプリごとのフロントエンドと FastAPI バックエンドを含む共通イメージビルド
- next-token のモデル設定と Hugging Face キャッシュ volume
- Docker Compose 設定の CI 構文検証

### 対象外・未確認
- ユーザー認証、データベース、永続的なユーザーデータ
- 可用性目標、負荷目標、SLA、バックアップ、監査ログ
- 各アプリの詳細な画面・計算ロジックの全仕様
- Azure リソースの IaC や自動デプロイ。現在確認できた workflow は Compose 構成検証のみ

## 4. 機能要件

| ID | 要件 | 現行実装・根拠 |
|---|---|---|
| FR-01 | `/` で4アプリへの入口リンクを提供する | `gateway/index.html` |
| FR-02 | `/word-vector/` を word-vector サービスへ転送する | `gateway/nginx.conf` |
| FR-03 | `/next-token/` を next-token サービスへ転送する | 同上 |
| FR-04 | `/attention/` を attention サービスへ転送する | 同上 |
| FR-05 | `/tokenizer/` を tokenizer サービスへ転送する | 同上 |
| FR-06 | サブパスなしの各アプリURLを末尾 `/` 付きへリダイレクトする | gateway の Nginx 設定 |
| FR-07 | 各アプリの frontend をビルドし、静的配信する | `apps/base/Dockerfile`, `apps/base/nginx-app.conf` |
| FR-08 | 各アプリの FastAPI を Uvicorn で起動する | `apps/base/supervisord.conf` と Compose の `BACKEND_MODULE` |
| FR-09 | API を各アプリの `/backend/` 配下で内部バックエンドに転送する | アプリ内 Nginx 設定 |
| FR-10 | next-token のモデル実行設定を Compose から注入する | `MODEL_ID`, `DEVICE`, `MAX_NEW_TOKENS`, `TOP_K`, `TEMPERATURE`, `HF_HOME` |
| FR-11 | next-token のモデルキャッシュを named volume に保持する | `hf-cache:/models` |
| FR-12 | push 時に Compose の設定を検証する | `.github/workflows/ci-cd.yml` の `docker compose config` |

## 5. アプリ単位の利用機能（確認範囲）

| アプリ | 利用者が入力するもの | 返る/表示されるもの | 主要処理 |
|---|---|---|---|
| Word Vector | 2〜10個の単語、PCA/UMAP、metric 等 | 2D scatter plot、単語間 matrix | SentenceTransformer embedding、PCA/UMAP、matrix 計算 |
| Next Token | 入力テキスト | 生成テキスト、ステップ別候補と確率 | Hugging Face causal LM による生成と trace |
| Attention | テキスト（画面の文字数上限は1000） | トークン列、attention arc、heatmap | Japanese BERT の attention を取得・平均 |
| Tokenizer | 入力テキスト | Sudachi形態素、品詞、BERT subword/token ID | Sudachi SplitMode C と BERT tokenizer |

詳細は `03-api-spec.md` と `04-ui-use-cases.md` を参照。

## 6. 外部インターフェース要件

### 6.1 HTTP / URL
- Gateway はコンテナのポート 80 をホストのポート 80 に公開する。
- 各アプリコンテナはポート 8080 で待ち受ける。
- Gateway は Docker Compose の service name を使ってアプリへ接続する。
- 各アプリ内 Nginx は `/` で SPA の `index.html` を fallback として返す。
- 各アプリ内 Nginx は `/backend/` を同一コンテナの `127.0.0.1:8000` に転送する。

### 6.2 サブモジュール
- Word Vector: `AI-UCDS-llm-word-vector-visualizer` (`main`)
- Next Token: `AI-UCDS-llm-next-token-predictor` (`master`)
- Attention: `AI-UCDS-llm-attention-visualizer` (`master`)
- Tokenizer: `AI-UCDS-llm-tokenizer-visualizer` (`master`)

### 6.3 モデル・外部依存
アプリ起動/解析時に Hugging Face モデル等を取得する実装がある。ネットワーク、モデル配布先の可用性、モデルライセンス、初回ロード時間はデプロイ環境で確認すること。

## 7. 非機能要件と現状

| 分類 | 現状から確認できる事項 | 未定義事項 |
|---|---|---|
| 保守性 | 共通 Dockerfile と個別 submodule に分割 | 共通API契約・バージョン互換ルール |
| 可搬性 | Docker Compose、Node 20 build、Python 3.11 runtime | Azure以外を含む公式対応環境一覧 |
| 性能 | next-token の CPU 設定が Compose にある。プロキシ timeout は設定済み | 応答時間、同時接続数、メモリ目標 |
| 可用性 | supervisord が backend/nginx を autorestart | readiness probe、Compose healthcheck、冗長化 |
| セキュリティ | コンテナ内ループバックの backend、HTTP reverse proxy | TLS終端、認証、レート制限、CSP等 |
| ログ | アプリ内 Nginx/supervisor の標準出力・標準エラー | 集約、保持期間、個人情報の扱い |
| CI | Compose 設定構文検証 | テスト、イメージbuild、脆弱性スキャン、デプロイ |

## 8. 制約・確認事項

1. `depends_on` はサービスの起動順序を表すが、アプリの readiness 完了まで待つ healthcheck は Compose に定義されていない。
2. Dockerfile は `npm ci || npm install` としている。lockfileを使った再現性が必要なら、`npm ci` の失敗時に install へフォールバックする方針を再評価する。
3. 次トークン生成はモデルのロードが必要で、Compose の設定は `DEVICE=cpu`。モデルサイズとホストのメモリ要件は実環境で計測が必要。
4. 各 submodule の frontend API URL は統合ビルド時に `rewrite-api.cjs` が調整する設計。相対APIパスの追加時には rewrite 対象と gateway 経由の動作を確認する。
5. API 側の health endpoint はアプリにより `/health` と `/api/health` が異なる。統合監視を設ける場合は共通化が必要。
6. 本書のURL/API例はアプリコードが持つ内部パスと公開サブパスを分けて記載する。

## 9. 受入条件（現行構成を基準とする）

- `docker compose config` が成功する。
- `docker compose up --build` で gateway と4つのアプリサービスが起動する。
- `/` に4アプリへのリンクが表示される。
- 各公開サブパスから対応するアプリ画面が表示される。
- 各アプリからのAPIリクエストが当該サービスの FastAPI に届く。
- next-token の設定値がコンテナ環境に渡され、`hf-cache` volume が `/models` に mount される。

> これらは受入テストとして推奨する条件であり、現在の CI が全項目を自動テストしているという意味ではない。
