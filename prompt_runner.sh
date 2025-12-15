#!/usr/bin/env bash
set -e

# Configuration
API_URL="http://localhost:8000/v1/chat/completions"
MODEL="Qwen/Qwen3-0.6B"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Helper function to run a single prompt
run_prompt() {
    local prompt_text="$1"
    local id="$2"
    local stats_file="$3"
    
    # Capture start time (nanoseconds)
    start_time=$(date +%s%N)
    
    response=$(curl -s "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$MODEL\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt_text\"}],
            \"temperature\": 0.7
        }")
    
    # Capture end time
    end_time=$(date +%s%N)
    duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [ -z "$response" ]; then
        echo -e "${RED}[ERROR]${NC} Request $id failed (empty response)."
        return
    fi

    # Use python to parse and format the output reliably
    # We also extract the answer length to estimate tokens
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

prompt = \"\"\"$prompt_text\"\"\"
id = \"$id\"
duration = \"$duration_ms\"
stats_file = \"$stats_file\"

# Regex to find thinking block
think_match = re.search(r'<think>(.*?)</think>', content, re.DOTALL)
thinking = think_match.group(1).strip() if think_match else None
answer = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()
full_text = (thinking or '') + answer
approx_tokens = len(full_text) // 4  # Rough estimate

# Append stats to file safely
if stats_file:
    with open(stats_file, 'a') as f:
        f.write(f'{duration},{approx_tokens}\n')

print(f'\033[0;32m[DONE]\033[0m id={id} time={duration}ms tokens~={approx_tokens}')
print(f'\033[1mQUESTION:\033[0m {prompt}')
if thinking:
    print(f'\033[0;33mTHINKING:\033[0m\n{thinking}')
print(f'\033[0;34mANSWER:\033[0m\n{answer}')
print('-' * 50)
" <<< "$response"
}

# Wrapper to run simple tasks in background
run_batch() {
    local category="$1"
    shift
    local prompts=("$@")
    
    # Create temp file for stats
    STATS_FILE=$(mktemp)
    
    echo -e "🚀 Starting ${category} batch with ${#prompts[@]} prompts..."
    echo -e "📊 Collecting stats to ${STATS_FILE}..."
    
    batch_start=$(date +%s%N)
    
    pids=()
    for i in "${!prompts[@]}"; do
        prompt="${prompts[$i]}"
        run_prompt "$prompt" "${category}-$i" "$STATS_FILE" &
        pids+=($!)
    done
    
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    batch_end=$(date +%s%N)
    batch_duration_ms=$(( (batch_end - batch_start) / 1000000 ))
    batch_duration_sec=$(echo "scale=2; $batch_duration_ms / 1000" | bc)
    
    echo -e "✅ ${category} batch complete."
    
    # Calculate Summary
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}       PERFORMANCE SUMMARY ($category)      ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -s "$STATS_FILE" ]; then
        python3 -c "
import sys
stats_file = \"$STATS_FILE\"
total_wall_time = $batch_duration_sec

times = []
tokens = []

try:
    with open(stats_file, 'r') as f:
        for line in f:
            t, tok = map(int, line.strip().split(','))
            times.append(t)
            tokens.append(tok)
except Exception as e:
    print(f'Error reading stats: {e}')
    sys.exit(0)

if times:
    count = len(times)
    total_tokens = sum(tokens)
    avg_latency = sum(times) / count
    min_latency = min(times)
    max_latency = max(times)
    
    # Throughput
    tps = total_tokens / total_wall_time if total_wall_time > 0 else 0
    rps = count / total_wall_time if total_wall_time > 0 else 0

    print(f'Total Requests:      {count}')
    print(f'Successful:          {count}') # assuming handled by error checks
    print(f'Total Wall Time:     {total_wall_time}s')
    print(f'Total Tokens (est):  {total_tokens}')
    print(f'----------------------------------------')
    print(f'Avg Latency:         {avg_latency:.2f} ms')
    print(f'Min Latency:         {min_latency} ms')
    print(f'Max Latency:         {max_latency} ms')
    print(f'----------------------------------------')
    print(f'Throughput (TPS):    {tps:.2f} tokens/sec')
    print(f'Throughput (RPS):    {rps:.2f} req/sec')
else:
    print('No data collected.')
"
    else
        echo "No stats data collected (all failed?)"
    fi
    echo -e "${BLUE}========================================${NC}"
    
    rm -f "$STATS_FILE"
}

case "$1" in
  sanity)
    run_prompt "Say hello!" "sanity-1"
    ;;
    
  creative)
    prompts=(
        "Write a haiku about rust programming."
        "Invent a new color and describe it."
        "What is the best way to cook an egg?"
        "Write a one-sentence horror story."
        "Explain quantum physics to a 5 year old."
    )
    run_batch "creative" "${prompts[@]}"
    ;;
    
  coding)
    prompts=(
        "Write a python function to reverse a string."
        "Explain the difference between TCP and UDP."
        "Write a bash script checking if a file exists."
        "What is a mutex?"
        "Write a SQL query to select all users over 18."
    )
    run_batch "coding" "${prompts[@]}"
    ;;
    
  stress)
    echo "🔥 Running STRESS test (50 parallel requests)..."
    prompts=()
    for i in {1..50}; do
        prompts+=("Stress test prompt number $i: What is $i + $i?")
    done
    run_batch "stress" "${prompts[@]}"
    ;;
    
  *)
    echo "Usage: $0 {sanity|creative|coding|stress}"
    exit 1
    ;;
esac
