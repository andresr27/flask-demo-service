# Use an official Python runtime as a base image with a specific version for reproducibility
FROM python:3.7-slim

# Set environment variables for Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_DEBUG=0
ENV FLASK_ENV=production

# Create a non-root user for security
RUN adduser --disabled-password --gecos '' appuser

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create .env file from build arguments (use config map and secrets instead)
# ARG REGISTRY_URL
# ARG API_URL
# RUN echo "REGISTRY_URL=$REGISTRY_URL" >> .env && \
#     echo "API_URL=$API_URL" >> .env

# Change ownership of the application directory
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose the port the app runs on
EXPOSE 5000

# Command to run the application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "3", "main:app"]