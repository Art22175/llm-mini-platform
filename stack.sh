#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

reset_model_env() {
  unset MODEL_ID MAX_MODEL_LEN GPU_MEMORY_UTILIZATION
}

choose_model_interactive() {
  echo
  echo "Select model to run:"
  echo "  1) Qwen3-0.6B (text-only)        -> Qwen/Qwen3-0.6B"
  echo "  2) Qwen3-VL-2B-Instruct (vision) -> Qwen/Qwen3-VL-2B-Instruct"
  echo
  read -r -p "Enter choice [1-2] (default: 1): " choice

  reset_model_env

  case "${choice:-1}" in
    1)
      export MODEL_ID="Qwen/Qwen3-0.6B"
      ;;
    2)
      export MODEL_ID="Qwen/Qwen3-VL-2B-Instruct"
      export MAX_MODEL_LEN="${MAX_MODEL_LEN:-16384}"
      export GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
      ;;
    *)
      echo "Invalid choice: $choice"
      exit 1
      ;;
  esac
}

apply_preset() {
  local preset="${1:-}"

  reset_model_env

  case "$preset" in
    "" )
      choose_model_interactive
      ;;
    0.6b|qwen3|text )
      export MODEL_ID="Qwen/Qwen3-0.6B"
      ;;
    2b-vl|vl|vl-2b )
      export MODEL_ID="Qwen/Qwen3-VL-2B-Instruct"
      export MAX_MODEL_LEN="${MAX_MODEL_LEN:-16384}"
      export GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
      ;;
    * )
      export MODEL_ID="$preset"
      ;;
  esac
}

wait_for_vllm() {
  echo "⏳ Waiting for vLLM API to become ready..."
  for i in {1..180}; do
    if curl -fsS http://localhost:8000/v1/models >/dev/null 2>&1; then
      echo "✅ vLLM is READY (http://localhost:8000)"
      return 0
    fi
    echo "  - still starting... (${i}/180)"
    sleep 2
  done

  echo "❌ vLLM did not become ready in time. Last logs:"
  docker logs --tail=120 vllm || true
  return 1
}

case "${1:-}" in
  up)
    # Optional non-interactive:
    #   ./stack.sh up 0.6b
    #   ./stack.sh up 2b-vl
    #   ./stack.sh up Qwen/Qwen3-VL-2B-Instruct
    apply_preset "${2:-}"

    echo "▶ Starting LLM mini platform"
    echo "   Model: ${MODEL_ID:-unset}"
    echo "   MAX_MODEL_LEN: ${MAX_MODEL_LEN:-default}"
    echo "   GPU_MEMORY_UTILIZATION: ${GPU_MEMORY_UTILIZATION:-default}"

    # Force-recreate vLLM so model/env changes always take effect
    docker compose up -d --force-recreate vllm
    docker compose up -d prometheus grafana

    wait_for_vllm
    ;;
  down)
    echo "⏹ Stopping LLM mini platform..."
    docker compose down
    ;;
  restart)
    echo "🔄 Restarting LLM mini platform..."
    docker compose down
    docker compose up -d --force-recreate
    ;;
  logs)
    docker compose logs -f
    ;;
  ps)
    docker compose ps
    ;;
  *)
    echo "Usage:"
    echo "  $0 up                # interactive model picker"
    echo "  $0 up 0.6b           # text model"
    echo "  $0 up 2b-vl          # vision-language model"
    echo "  $0 up <hf-repo>      # any HuggingFace repo id"
    echo "  $0 down | restart | logs | ps"
    exit 1
    ;;
esac
