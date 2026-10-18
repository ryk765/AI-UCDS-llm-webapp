# AI-UCDS LLM WebApp (Unified)

## Local run
```bash
docker compose up --build
```

Open:
- http://localhost/
- http://localhost/word-vector/
- http://localhost/next-token/
- http://localhost/attention/
- http://localhost/tokenizer/

## Azure (Web App for Containers, Compose)
1. Push this repo to GitHub
2. Create ACR
3. Create Linux App Service Plan
4. Create Web App (multi-container) and point to this compose setup
```