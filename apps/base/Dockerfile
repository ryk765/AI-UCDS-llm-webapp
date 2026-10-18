# ---------- Stage 1: frontend build ----------
FROM node:20-slim AS frontend
ARG APP_DIR
ARG APP_SLUG
WORKDIR /build

COPY ${APP_DIR}/frontend/package*.json ./
RUN npm ci || npm install

COPY ${APP_DIR}/frontend/ ./

# ソースは変えず、ビルド時だけAPI接続先をサブパス用に書き換える
RUN find src -type f \( -name '*.ts' -o -name '*.tsx' \) -exec sed -i \
      -e "s#http://localhost:8000#/${APP_SLUG}/backend#g" \
      -e "s#\"/api/#\"/${APP_SLUG}/backend/api/#g" {} + && \
    mkdir -p src && \
    ( [ -f src/vite-env.d.ts ] || echo '/// <reference types="vite/client" />' > src/vite-env.d.ts )

ENV VITE_API_BASE=/${APP_SLUG}/backend
ENV VITE_API_BASE_URL=/${APP_SLUG}/backend
RUN npm run build -- --base=./

# ---------- Stage 2: runtime ----------
FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      nginx supervisor build-essential curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Rust（sudachipy などの source build 用）
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

COPY --from=frontend /build/dist /usr/share/app/dist
COPY apps/base/nginx-app.conf /etc/nginx/nginx.conf
COPY apps/base/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 8080
CMD ["supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]