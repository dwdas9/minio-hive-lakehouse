FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy producer script
COPY crypto_producer.py .

# Run the producer
CMD ["python", "-u", "crypto_producer.py"]
