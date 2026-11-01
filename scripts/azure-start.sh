#!/usr/bin/env bash
set -u

RG="ItoLabResourceGroup2026"
APPS=(gateway word-vector next-token attention tokenizer)

# 1) 全アプリを min-replicas=1 にする
for app in "${APPS[@]}"; do
  echo "Starting $app ..."
  az containerapp update -g "$RG" -n "$app" --min-replicas 1 --max-replicas 1 >/dev/null \
    && echo "  OK" || echo "  FAILED: $app"
done

FQDN=$(az containerapp show -g "$RG" -n gateway --query properties.configuration.ingress.fqdn -o tsv)
URL="https://$FQDN"
echo "URL: $URL"

# 2) health を待つ（最大 約5分）
wait_health() {
  local name="$1" path="$2"
  for i in $(seq 1 30); do
    code=$(curl -s -o /dev/null -m 20 -w "%{http_code}" "$URL$path")
    if [ "$code" = "200" ]; then
      echo "  [OK] $name"
      return 0
    fi
    sleep 10
  done
  echo "  [NG] $name (最後のHTTP: $code)"
  return 1
}

echo "health 確認中 ..."
wait_health "tokenizer"  "/tokenizer/backend/health"
wait_health "attention"  "/attention/backend/health"
wait_health "next-token" "/next-token/backend/api/health"
wait_health "word-vector" "/word-vector/"

# 3) next-token のモデルを事前に読み込む（ウォームアップ）
echo "next-token のモデルを読み込み中（数分かかることがあります）..."
code=$(curl -s -o /dev/null -m 600 -w "%{http_code}" -X POST "$URL/next-token/backend/api/generate" \
  -H "Content-Type: application/json" \
  -d '{"input_text":"今日は天気が良いので、"}')
echo "  warm-up HTTP: $code"

echo "完了: $URL"
