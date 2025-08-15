FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY api_server.py .

# Create directories
RUN mkdir -p /app/uploads /app/processed

# Expose port
EXPOSE 3001

# Run the server
CMD ["python", "api_server.py"]