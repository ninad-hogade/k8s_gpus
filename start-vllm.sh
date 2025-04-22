#!/bin/bash

# Get pod ordinal for port assignment
ORDINAL=$(echo $HOSTNAME | rev | cut -d'-' -f1 | rev)
PORT=$((8000 + $ORDINAL))
echo "Starting vLLM server on pod $HOSTNAME with port $PORT"

# Check MPS environment
echo "Checking MPS environment..."
echo "CUDA_MPS_PIPE_DIRECTORY: $CUDA_MPS_PIPE_DIRECTORY"
echo "CUDA_MPS_LOG_DIRECTORY: $CUDA_MPS_LOG_DIRECTORY"
ls -la $CUDA_MPS_PIPE_DIRECTORY || echo "Cannot access MPS pipe directory"

# Check NVIDIA configuration
nvidia-smi || echo "nvidia-smi not available"

# Start vLLM server
echo "Starting vLLM server with TinyLlama model in MPS mode..."

# Use the locally downloaded model
python -m vllm.entrypoints.openai.api_server \
  --host 0.0.0.0 \
  --port $PORT \
  --model /app/models/TinyLlama-1.1B-Chat-v1.0 \
  --gpu-memory-utilization 0.4 \
  --max-model-len 512 \
  --tensor-parallel-size 1