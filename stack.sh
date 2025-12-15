#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$PROJECT_DIR"

case "$1" in
  up)
    echo "▶ Starting LLM mini platform..."
    docker compose up -d

    echo "⏳ Waiting for vLLM API to become ready..."
    for i in {1..60}; do
      if curl -fsS http://localhost:8000/v1/models >/dev/null 2>&1; then
        echo "✅ vLLM is READY (http://localhost:8000)"
        break
      fi
      echo "  - still starting... (${i}/60)"
      sleep 2
    done
    ;;
  down)
    echo "⏹ Stopping LLM mini platform..."
    docker compose down
    ;;
  restart)
    echo "🔄 Restarting LLM mini platform..."
    docker compose down
    docker compose up -d
    ;;
  logs)
    docker compose logs -f
    ;;
  ps)
    docker compose ps
    ;;
  *)
    echo "Usage: $0 {up|down|restart|logs|ps}"
    exit 1
    ;;
esac
