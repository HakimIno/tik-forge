# Build stage
FROM ubuntu:22.04 AS builder

# Install essential build tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && wget https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz \
    && tar xf zig-linux-x86_64-0.11.0.tar.xz \
    && mv zig-linux-x86_64-0.11.0 /usr/local/zig \
    && rm zig-linux-x86_64-0.11.0.tar.xz \
    && rm -rf /var/lib/apt/lists/*

# Add Zig to PATH
ENV PATH="/usr/local/zig:${PATH}"

# Set working directory
WORKDIR /build

# Copy only necessary files
COPY package*.json ./
COPY scripts/ ./scripts/
COPY src/ ./src/
COPY build.zig ./
COPY binding.gyp ./

# Install only necessary dependencies and build
RUN npm ci --only=production \
    && npm cache clean --force \
    && npm run build:only

# Runtime stage
FROM ubuntu:22.04

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only the built files from builder
COPY --from=builder /build/build/Release/tik-forge.node ./build/Release/
COPY --from=builder /build/package.json ./
COPY test.js ./

# Run tests
CMD ["node", "test.js"]