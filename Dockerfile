# ------------------------------
#   Builder: download shell2http
# ------------------------------
FROM alpine:3.20 AS builder

ARG SHELL2HTTP_VERSION=1.15.0
RUN apk add --no-cache curl \
 && curl -L -o /shell2http.tar.gz \
      https://github.com/msoap/shell2http/releases/download/${SHELL2HTTP_VERSION}/shell2http_${SHELL2HTTP_VERSION}_linux_amd64.tar.gz \
 && tar xf /shell2http.tar.gz \
 && mv shell2http /shell2http


# ------------------------------
#   Final image
# ------------------------------
FROM alpine:3.20

# Install only what we need
RUN apk add --no-cache bash jq openssl

# Directories
WORKDIR /app
RUN mkdir -p /app/server

# Copy shell2http from builder
COPY --from=builder /shell2http /usr/local/bin/shell2http

# Copy broker scripts
COPY server/ /app/server/

# Expose port (default is 8080; override with .env if needed)
EXPOSE 8080

# Environment file (optional)
# Users can mount their own .env at runtime:
#   docker run -v $(pwd)/.env:/app/server/.env ...
ENV ENV_FILE="/app/server/.env"

# Start broker
ENTRYPOINT ["/bin/bash", "/app/server/run.sh"]
