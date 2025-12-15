# LLM Mini Platform (vLLM + Prometheus + Grafana)

A minimal, reproducible local LLM platform using:
- vLLM
- Qwen3-0.6B
- Prometheus
- Grafana
- Docker Compose

## Requirements
- Ubuntu 22.04+ (24.04 tested)
- Docker + Docker Compose v2
- NVIDIA GPU + NVIDIA Container Toolkit

## Quick start
```bash
git clone <this-repo>
cd llm-mini-platform
chmod +x stack.sh prompt.sh
./stack.sh up
LLM API: http://localhost:8000
Grafana: http://localhost:3000
Prometheus: http://localhost:9090

GPU note
This setup expects an NVIDIA GPU.
For CPU-only usage, remove the deploy.resources.reservations.devices section
from docker-compose.yml.

Stop everything
bash
Copy code
./stack.sh down