FROM ubuntu:22.04

# Install system dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    curl \
    libreadline-dev \
    tcl-dev \
    neovim \
    && rm -rf /var/lib/apt/lists/*

ENV EDITOR=nvim
RUN echo 'alias vim="nvim"' >> ~/.bashrc

# Install OSS CAD Suite
ARG OSS_CAD_DATE="2025-01-20"
ARG ARCH="linux-x64" 
# NOTE: If you are on an M1/M2/M3 Mac, change ARCH above to "linux-arm64"

RUN date_compact=$(echo ${OSS_CAD_DATE} | tr -d '-') && \
    curl -L https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_DATE}/oss-cad-suite-${ARCH}-${date_compact}.tgz \
    | tar -xzC /opt

# Update PATH so you can type 'make', 'yosys', or 'verilator' directly
ENV PATH="/opt/oss-cad-suite/bin:${PATH}"

# 4. (Optional) Install Python dependencies for your specific assignment
# If you have a requirements.txt, uncomment the next two lines:
# COPY requirements.txt .
# RUN pip3 install --no-cache-dir -r requirements.txt

# Set working directory
WORKDIR /assignment

# Default command: Start a bash shell
CMD ["/bin/bash"]
