# syntax=docker/dockerfile:1
FROM rust:1-slim-bookworm AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y pkg-config libssl-dev perl make && rm -rf /var/lib/apt/lists/*
RUN set -e; \
    apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    git \
    || (for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources; do \
          if [ -f "$f" ]; then \
            sed -i 's|http://deb.debian.org|https://mirrors.aliyun.com|g' "$f"; \
            sed -i 's|http://security.debian.org|https://mirrors.aliyun.com|g' "$f"; \
            sed -i 's|https://deb.debian.org|https://mirrors.aliyun.com|g' "$f"; \
            sed -i 's|https://security.debian.org|https://mirrors.aliyun.com|g' "$f"; \
          fi; \
        done; \
        apt-get update && apt-get install -y --no-install-recommends --fix-missing \
        pkg-config libssl-dev git); \
    rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY xtask ./xtask
COPY agents ./agents
COPY packages ./packages
# Optional build args for dev environments to speed up compilation
# Example: docker build --build-arg LTO=false --build-arg CODEGEN_UNITS=16 .
ARG LTO=true
ARG CODEGEN_UNITS=1
ENV CARGO_PROFILE_RELEASE_LTO=${LTO} \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=${CODEGEN_UNITS}
RUN cargo build --release --bin openfang
RUN cargo install --locked rust-mcp-filesystem --root /opt/rust-mcp-filesystem

FROM rust:1-slim-bookworm
RUN set -e; \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    || (for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources; do \
          if [ -f "$f" ]; then \
            sed -i 's|http://deb.debian.org|https://mirrors.aliyun.com|g' "$f"; \
            sed -i 's|http://security.debian.org|https://mirrors.aliyun.com|g' "$f"; \
            sed -i 's|https://deb.debian.org|https://mirrors.aliyun.com|g' "$f"; \
            sed -i 's|https://security.debian.org|https://mirrors.aliyun.com|g' "$f"; \
          fi; \
        done; \
        apt-get update && apt-get install -y --no-install-recommends --fix-missing \
        ca-certificates curl git python3 python3-pip python3-venv nodejs npm); \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/iOfficeAI/OfficeCLI/main/install.sh | bash \
    && mv "$HOME/.local/bin/officecli" /usr/local/bin/officecli

COPY --from=builder /build/target/release/openfang /usr/local/bin/
COPY --from=builder /opt/rust-mcp-filesystem/bin/rust-mcp-filesystem /usr/local/bin/
COPY --from=builder /build/agents /opt/openfang/agents
EXPOSE 4200
VOLUME /data
ENV OPENFANG_HOME=/data
ENTRYPOINT ["openfang"]
CMD ["start"]
