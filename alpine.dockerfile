# syntax=docker.io/docker/dockerfile:1
ARG PLAT=musllinux_1_2_riscv64
ARG IMAGE=quay.io/pypa/${PLAT}:2026.02.01-1
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.1-r1

FROM --platform=linux/riscv64 ${IMAGE} AS base

# Install guest tools
ARG MACHINE_GUEST_TOOLS_VERSION
ADD --chmod=644 https://edubart.github.io/linux-packages/apk/keys/cartesi-apk-key.rsa.pub /etc/apk/keys/cartesi-apk-key.rsa.pub
RUN echo "https://edubart.github.io/linux-packages/apk/stable" >> /etc/apk/repositories
RUN apk update && \
    apk add cartesi-machine-guest-tools=${MACHINE_GUEST_TOOLS_VERSION} \
    cartesi-machine-guest-libcmt-dev=${MACHINE_GUEST_TOOLS_VERSION} \
    build-base=0.5-r3

FROM base AS builder

COPY . /opt/build

ARG PLAT
ENV PLAT=${PLAT}

WORKDIR /opt/build

# RUN /opt/build/build_wheels.sh
