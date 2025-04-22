FROM nvcr.io/nvidia/pytorch:23.12-py3

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-pip git build-essential gcc g++ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install "optree>=0.13.0" && \
    pip install vllm flask

# Pre-download the model using a different approach
RUN pip install huggingface_hub && \
    python -c "from huggingface_hub import snapshot_download; snapshot_download('TinyLlama/TinyLlama-1.1B-Chat-v1.0', local_dir='/app/models/TinyLlama-1.1B-Chat-v1.0')"

# Set working directory
WORKDIR /app

# Copy your application code
COPY start-vllm.sh /app/

# Make the script executable
RUN chmod +x /app/start-vllm.sh

# Default command
CMD ["/app/start-vllm.sh"]