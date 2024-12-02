FROM --platform=$TARGETPLATFORM node:${NODE_VERSION}

# Install Zig
RUN apt-get update && apt-get install -y wget xz-utils
RUN wget https://ziglang.org/download/0.13.0/zig-linux-aarch64-0.13.0.tar.xz \
    && tar xf zig-linux-aarch64-0.13.0.tar.xz \
    && mv zig-linux-aarch64-0.13.0 /usr/local/zig \
    && ln -s /usr/local/zig/zig /usr/local/bin/zig

WORKDIR /app
COPY . .

# Build
RUN npm install
RUN npm run build