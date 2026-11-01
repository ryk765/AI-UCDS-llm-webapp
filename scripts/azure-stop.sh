#!/usr/bin/env bash
set -u

RG="ItoLabResourceGroup2026"
APPS=(gateway word-vector next-token attention tokenizer)

for app in "${APPS[@]}"; do
  echo "Stopping $app ..."
  az containerapp update -g "$RG" -n "$app" --min-replicas 0 --max-replicas 1 >/dev/null \
    && echo "  OK" || echo "  FAILED: $app"
done

echo "完了: 全アプリを min-replicas=0 にしました。"
