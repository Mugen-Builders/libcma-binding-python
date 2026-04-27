# syntax=docker.io/docker/dockerfile:1
ARG PLAT=manylinux_2_39_riscv64
ARG IMAGE=quay.io/pypa/${PLAT}:2026.02.01-1
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.2
ARG MACHINE_GUEST_TOOLS_SHA=4cabfd5cfd932367a5be35fa6c18a541f9044f04c48ffcb38bea3cebf88cc6a7

FROM --platform=linux/riscv64 ${IMAGE} AS base

# Install guest tools
ARG MACHINE_GUEST_TOOLS_VERSION
ARG MACHINE_GUEST_TOOLS_SHA
ADD --checksum=sha256:${MACHINE_GUEST_TOOLS_SHA} \
    https://github.com/cartesi/machine-guest-tools/releases/download/v${MACHINE_GUEST_TOOLS_VERSION}/machine-guest-tools_riscv64.tar.gz \
    /tmp/machine-guest-tools_riscv64.tar.gz

ARG DEBIAN_FRONTEND=noninteractive
RUN tar zxvf /tmp/machine-guest-tools_riscv64.tar.gz -C /

FROM base AS builder

COPY . /opt/build

ARG PLAT
ENV PLAT=${PLAT}

WORKDIR /opt/build

# RUN /opt/build/build_wheels.sh
