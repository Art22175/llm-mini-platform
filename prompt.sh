#!/usr/bin/env bash
set -e

PROMPT="${1:-Dont respond with anything but saying: Its me Qwen 0.6b and I am ready!.}"
API_URL="http://localhost:8000/v1/chat/completions"
MODEL="Qwen/Qwen3-0.6B"

# Capture start time (nanoseconds)
start_time=$(date +%s%N)

response=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"$PROMPT\"}
    ],
    \"temperature\": 0.2
  }")

# Capture end time
end_time=$(date +%s%N)
duration_ms=$(( (end_time - start_time) / 1000000 ))

if [ -z "$response" ]; then
    echo "Error: Empty response from server"
    exit 1
fi

# Use python to parse and format the output reliably, similar to prompt_runner.sh
python3 -c "
import sys, re, json

try:
    raw_response = sys.stdin.read()
    data = json.loads(raw_response)
    content = data['choices'][0]['message']['content']
except Exception as e:
    print(f'\033[0;31m[ERROR]\033[0m Failed to parse JSON: {e}')
    print(raw_response)
    sys.exit(1)

prompt = \"\"\"$PROMPT\"\"\"
duration = \"$duration_ms\"

# Regex to find thinking block
think_match = re.search(r'<think>(.*?)</think>', content, re.DOTALL)
thinking = think_match.group(1).strip() if think_match else None
answer = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()

print(f'\033[0;32m[DONE]\033[0m time={duration}ms')
print(f'\033[1mQUESTION:\033[0m {prompt}')
if thinking:
    print(f'\033[0;33mTHINKING:\033[0m\n{thinking}')
print(f'\033[0;34mANSWER:\033[0m\n{answer}')
print('-' * 50)
" <<< "$response"
