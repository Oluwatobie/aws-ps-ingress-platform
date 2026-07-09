# Use a lightweight, hardened python base image
FROM python:3.11-slim

# Enforce Python outputs to stream straight to terminal/CloudWatch logs without buffering
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy requirements and install dependencies
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application script
COPY app/worker.py .

# Security hardening: Run the container as a non-root application user
RUN useradd -u 8888 appuser && chown -R appuser:appuser /app
USER appuser

CMD ["python", "worker.py"]