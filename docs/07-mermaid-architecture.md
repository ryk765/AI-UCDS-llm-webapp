# AI-UCDS LLM WebApp Mermaid 構成図

本ファイルは、READMEや設計書へ転記できる構成図の独立版である。

## 1. システムコンテキスト図

```mermaid
flowchart LR
    User[利用者 / Browser] -->|HTTP| Unified[AI-UCDS LLM WebApp]
    Unified --> WV[Word Vector Visualizer]
    Unified --> NT[Next Token Predictor]
    Unified --> AV[Attention Visualizer]
    Unified --> TV[Tokenizer Visualizer]
    NT -.モデル取得/キャッシュ.-> HF[Hugging Face Hub / Cache]
    WV -.モデル取得.-> HF
    AV -.モデル取得.-> HF
    TV -.tokenizer取得.-> HF
```

## 2. コンテナ構成図

```mermaid
flowchart TB
  Browser[Browser] -->|localhost:80 / App Service HTTP| Gateway[Gateway Nginx :80]
  Gateway -->|service DNS :8080| WV[word-vector container :8080]
  Gateway -->|service DNS :8080| NT[next-token container :8080]
  Gateway -->|service DNS :8080| AT[attention container :8080]
  Gateway -->|service DNS :8080| TK[tokenizer container :8080]

  subgraph AppContainer[各アプリ共通のコンテナ構成]
    Static[Frontend build artifacts: /usr/share/app/dist] --> AppNginx[Nginx :8080]
    AppNginx -->|/backend/| Uvicorn[Uvicorn / FastAPI :8000 on loopback]
    Supervisor[Supervisord] -.プロセス管理.-> AppNginx
    Supervisor -.プロセス管理.-> Uvicorn
  end

  NT --> Cache[(hf-cache volume mounted at /models)]
```

## 3. URLルーティング図

```mermaid
flowchart LR
  R0[GET /] --> Home[gateway/index.html]
  R1[/word-vector/] --> W[service: word-vector]
  R2[/next-token/] --> N[service: next-token]
  R3[/attention/] --> A[service: attention]
  R4[/tokenizer/] --> T[service: tokenizer]
  W --> WUI[App Nginx: static UI]
  W --> WAPI[App Nginx /backend/ → FastAPI]
  N --> NUI[App Nginx: static UI]
  N --> NAPI[App Nginx /backend/ → FastAPI]
  A --> AUI[App Nginx: static UI]
  A --> AAPI[App Nginx /backend/ → FastAPI]
  T --> TUI[App Nginx: static UI]
  T --> TAPI[App Nginx /backend/ → FastAPI]
```

## 4. ビルドシーケンス

```mermaid
flowchart TD
  Compose[docker compose build] --> Shared[apps/base/Dockerfile]
  Shared --> Args[APP_DIR / APP_SLUG / BACKEND_MODULE]
  Args --> Node[Node 20 frontend stage]
  Node --> Install[npm dependencies]
  Install --> Rewrite[rewrite-api.cjs: API URL adjustment]
  Rewrite --> Vite[Vite build --base=./]
  Vite --> Runtime[Python 3.11 runtime stage]
  Runtime --> PyDeps[Install backend requirements]
  Runtime --> CopyDist[Copy frontend dist]
  PyDeps --> AppImage[App container image]
  CopyDist --> AppImage
  AppImage --> Start[Supervisord starts Nginx + Uvicorn]
```

## 5. アプリ内部処理フロー

```mermaid
flowchart LR
  Input[User input] --> UI[React UI]
  UI -->|JSON HTTP request| Gateway[Gateway]
  Gateway --> AppNginx[App Nginx]
  AppNginx -->|/backend prefix removed| API[FastAPI route]
  API --> Logic[Service / Analyzer]
  Logic --> Model[Model or tokenizer]
  Model --> Logic
  Logic -->|JSON response| API
  API --> AppNginx
  AppNginx --> Gateway
  Gateway --> UI
```

## 6. 注意

- Gateway Nginx はサービス名を使い、各アプリコンテナのポート8080へ転送する。
- アプリ内 Nginx は `/backend/` を `127.0.0.1:8000/` へ転送する。
- 統合ビルド時の API URL 調整は `apps/base/rewrite-api.cjs` による。
- 図は現行コードの構成を表す。healthcheck、TLS終端、認証、冗長化は図示/実装されていない。
