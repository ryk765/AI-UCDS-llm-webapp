#!/usr/bin/env bash
set -e
cd /opt/app/src

# Find likely FastAPI entrypoint candidates
candidates=(
  "main:app"
  "app.main:app"
  "server:app"
  "src.main:app"
  "backend.main:app"
)

for c in "${candidates[@]}"; do
  python - <<PY >/dev/null 2>&1 && exec uvicorn "$c" --host 0.0.0.0 --port 8000
import importlib
mod, attr = "$c".split(":")
m = importlib.import_module(mod)
getattr(m, attr)
PY
done

# Fallback: grep app = FastAPI(
target=$(grep -R --line-number "FastAPI(" . | head -n 1 | cut -d: -f1 || true)
if [ -n "$target" ]; then
  mod=$(echo "$target" | sed 's#^\./##; s#/#.#g; s#\.py$##')
  exec uvicorn "${mod}:app" --host 0.0.0.0 --port 8000
fi

echo "[ERROR] FastAPI entrypoint not found."
sleep 3600