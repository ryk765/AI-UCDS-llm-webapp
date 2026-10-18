#!/usr/bin/env bash
set -e
cd /opt/app/src

if [ -f package.json ]; then
  # Prefer built static with serve
  if [ -d dist ]; then
    exec npx serve -s dist -l 3000
  fi
  if [ -d build ]; then
    exec npx serve -s build -l 3000
  fi
  # Fallback dev server
  exec npm run dev -- --host 0.0.0.0 --port 3000
fi

# No frontend found
python -m http.server 3000