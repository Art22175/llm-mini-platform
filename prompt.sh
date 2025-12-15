#!/usr/bin/env bash
set -e

PROMPT="${1:-Dont respond with anything but saying: Its me Qwen 0.6b and I am ready!.}"

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
