#!/usr/bin/env bash
set -e

PROMPT="${1:-Say hi in one short sentence.}"

curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"Qwen/Qwen3-0.6B\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"$PROMPT\"}
    ],
    \"temperature\": 0.2
  }" \
| python3 -m json.tool
