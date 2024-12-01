FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies first
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    xz-utils \
    git \
    build-essential \
    file \
    wkhtmltopdf \
    xvfb \
    gnumeric \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js from NodeSource and development files
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g node-gyp \
    && apt-get install -y --no-install-recommends \
    libnode-dev \
    --allow-downgrades \
    --allow-overwrite \
    && rm -rf /var/lib/apt/lists/*

# Setup wkhtmltopdf with xvfb
RUN echo '#!/bin/bash\nxvfb-run -a --server-args="-screen 0, 1024x768x24" /usr/bin/wkhtmltopdf "$@"' > /usr/local/bin/wkhtmltopdf.sh && \
    chmod +x /usr/local/bin/wkhtmltopdf.sh

# Install Zig
WORKDIR /tmp
RUN wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz \
    && tar xf zig-linux-x86_64-0.13.0.tar.xz \
    && mv zig-linux-x86_64-0.13.0 /usr/local/zig \
    && ln -s /usr/local/zig/zig /usr/local/bin/zig \
    && rm zig-linux-x86_64-0.13.0.tar.xz

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy source files
COPY . .

# Setup directories
RUN mkdir -p /app/tmp /app/output && \
    chmod 777 /app/tmp /app/output

# Debug: Show library paths
RUN echo "=== Library Paths ===" && \
    ldconfig -p | grep node

# Debug: Show Node.js version and location
RUN node --version && \
    which node && \
    echo "=== Node.js Files ===" && \
    find / -name "libnode*" 2>/dev/null || true

# Debug: Show library paths after installing libnode-dev
RUN echo "=== Library Paths ===" && \
    ldconfig -p | grep node && \
    echo "=== Node.js Files ===" && \
    ls -la /usr/lib/x86_64-linux-gnu/libnode* || true && \
    echo "=== Node.js Include Files ===" && \
    ls -la /usr/include/node/ || true

# Build with verbose output
RUN zig build --verbose && \
    mkdir -p build/Release && \
    cp zig-out/lib/libtik-forge.so build/Release/tik-forge.node

# Environment variables
ENV NODE_ENV=development
ENV DEBUG=*
ENV PDF_ENGINE=/usr/local/bin/wkhtmltopdf.sh
ENV TEMP_DIR=/app/tmp
ENV NODE_PATH=/usr/lib/node_modules
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu

# Volume for output
VOLUME ["/app/output"]

CMD ["node", "test.js"]