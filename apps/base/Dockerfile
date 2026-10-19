# ---------- Stage 1: frontend build ----------
FROM node:20-slim AS frontend
ARG APP_DIR
ARG APP_SLUG
WORKDIR /build

COPY ${APP_DIR}/frontend/package*.json ./
RUN npm ci || npm install
COPY ${APP_DIR}/frontend/ ./

# API 呼び出し先をサブパス運用向けに統一
COPY apps/base/rewrite-api.cjs /rewrite-api.cjs
RUN node /rewrite-api.cjs "${APP_SLUG}" src

# Vite 環境変数（attention 等のため）
ENV VITE_API_BASE=/${APP_SLUG}/backend
ENV VITE_API_BASE_URL=/${APP_SLUG}/backend

# import.meta.env 型定義が無い場合を補完
RUN mkdir -p src && ( [ -f src/vite-env.d.ts ] || echo '/// <reference types="vite/client" />' > src/vite-env.d.ts )

RUN npm run build -- --base=./

# ---------- Stage 2: runtime ----------
FROM python:3.11-slim

# tokenizer/sudachi 系のビルド用に Rust も入れる
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor build-essential curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

ARG APP_DIR
ARG BACKEND_MODULE
ENV BACKEND_MODULE=${BACKEND_MODULE}

WORKDIR /app/backend
COPY ${APP_DIR}/backend/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt
COPY ${APP_DIR}/backend/ ./

# tokenizer で不足しやすい依存を保険で追加
RUN pip install --no-cache-dir fugashi unidic-lite sentencepiece protobuf

COPY --from=frontend /build/dist /usr/share/app/dist
COPY apps/base/nginx-app.conf /etc/nginx/nginx.conf
COPY apps/base/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 8080
CMD ["supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
