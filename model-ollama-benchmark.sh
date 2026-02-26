#!/bin/bash

set -e

OLLAMA_URL="http://localhost:11436"
RESULTS_FILE="results.md"
DATE_NOW=$(date +"%Y-%m-%d %H:%M:%S")

MODELS=(
  "lfm2:24b"
  "glm-4.7-flash:q4_K_M"
  "nemotron-3-nano:30b"
  "gemma3:27b"
)

PROMPTS=(
  "Write a 300 word essay about artificial intelligence."
  "Explain event driven architecture in detail."
  "Describe how GPUs accelerate neural networks."
)

# ===============================
# GPU INFORMATION
# ===============================

GPU_INFO="Unknown"

if command -v rocm-smi &> /dev/null; then
  GPU_INFO=$(rocm-smi --showproductname --showvram --json 2>/dev/null || rocm-smi)
elif command -v nvidia-smi &> /dev/null; then
  GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)
else
  GPU_INFO=$(lspci | grep -i vga)
fi

# ===============================
# PULL MODELS
# ===============================

echo "Pulling models..."

for model in "${MODELS[@]}"; do
  echo "Pulling $model"
  curl -s -X POST $OLLAMA_URL/api/pull \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$model\"}" > /dev/null
done

# ===============================
# WRITE MARKDOWN HEADER
# ===============================

echo "# Ollama Benchmark Results" > $RESULTS_FILE
echo "" >> $RESULTS_FILE
echo "**Date:** $DATE_NOW" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE
echo "## GPU Information" >> $RESULTS_FILE
echo '```' >> $RESULTS_FILE
echo "$GPU_INFO" >> $RESULTS_FILE
echo '```' >> $RESULTS_FILE
echo "" >> $RESULTS_FILE
echo "## Results" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE
echo "| Model | Total Tokens | Total Seconds | Tokens/s |" >> $RESULTS_FILE
echo "|-------|--------------|---------------|----------|" >> $RESULTS_FILE

# ===============================
# BENCHMARK
# ===============================

echo ""
echo "Date: $DATE_NOW"
echo ""
echo "GPU Information:"
echo "$GPU_INFO"
echo ""
printf "%-25s | %-12s | %-12s | %-10s\n" "MODEL" "TOKENS" "SECONDS" "TOKENS/S"
printf -- "--------------------------------------------------------------------------\n"

for model in "${MODELS[@]}"; do

  echo "Warmup: $model"

  curl -s -X POST $OLLAMA_URL/api/generate \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$model\",
      \"prompt\": \"warmup\",
      \"stream\": false
    }" > /dev/null

  total_tokens=0
  total_seconds=0

  for prompt in "${PROMPTS[@]}"; do
    response=$(curl -s -X POST $OLLAMA_URL/api/generate \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"$model\",
        \"prompt\": \"$prompt\",
        \"stream\": false
      }")

    error=$(echo "$response" | jq -r '.error // empty')

    if [ ! -z "$error" ]; then
      echo "Error with $model: $error"
      continue
    fi

    eval_count=$(echo "$response" | jq '.eval_count')
    eval_duration=$(echo "$response" | jq '.eval_duration')

    seconds=$(echo "scale=6; $eval_duration / 1000000000" | bc)

    total_tokens=$(echo "$total_tokens + $eval_count" | bc)
    total_seconds=$(echo "$total_seconds + $seconds" | bc)
  done

  avg_tps=$(echo "scale=2; $total_tokens / $total_seconds" | bc)

  printf "%-25s | %-12s | %-12s | %-10s\n" \
    "$model" \
    "$total_tokens" \
    "$total_seconds" \
    "$avg_tps"

  echo "| $model | $total_tokens | $total_seconds | $avg_tps |" >> $RESULTS_FILE

done

echo ""
echo "Benchmark complete."
echo "Results saved to $RESULTS_FILE"
