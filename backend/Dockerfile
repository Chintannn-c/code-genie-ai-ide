# Production Dockerfile for Code Genie Backend
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create data directories
RUN mkdir -p ../data/artifacts ../data/uploads

# Start the application using the Python runner (Ensures internal PORT logic is hit)
CMD ["python", "-m", "app.main"]
