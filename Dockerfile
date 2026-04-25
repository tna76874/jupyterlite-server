# Global ARG declarations
ARG PYTHON_VERSION=3.11-slim
ARG NGINX_VERSION=1.30.0-alpine-slim

# --- STAGE 1: Build Stage ---
FROM python:${PYTHON_VERSION} AS builder

WORKDIR /app

# Ensure pip is up to date and install frozen dependencies
RUN pip install --no-cache-dir --upgrade pip 
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy local notebooks/content
COPY ./content ./content

# Generate the static JupyterLite build
RUN jupyter lite build --contents content --output-dir dist

# --- STAGE 2: Execution Stage ---
ARG NGINX_VERSION
FROM quay.io/nginx/nginx-unprivileged:${NGINX_VERSION}

# Copy only the static assets from the builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]